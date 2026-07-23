#!/usr/bin/env bash
# Génère les deux sections encadrées du README depuis une source de vérité
# unique par table :
#   - Table A (matrice de résidus, marqueurs BEGIN/END GENERATED RESIDUE) :
#     rédigée dans ce script (heredoc RESIDUE_ROWS). Chaque cellule a été
#     vérifiée contre la doc de l'outil, le comportement CI et docs/journal.md
#     (voir docs/plans/10-readme-instrument.md).
#   - Table B (spécimens, marqueurs BEGIN/END GENERATED MATRIX) : dérivée des
#     scripts du dépôt et de la table SCRIPTS de check.sh, augmentée d'une
#     colonne de latence médiane par OS. Les latences sont un INSTANTANÉ figé
#     (heredoc LAT_FACTS) calculé depuis la branche `data` (data/runs.tsv) au
#     moment de la génération — figées ici pour que le générateur reste
#     déterministe et que la garde de fraîcheur CI (generate-readme.sh puis
#     git diff --exit-code) ne dérive pas quand de nouvelles lignes arrivent
#     sur la branche `data`.
#
# Ne remplace que l'intérieur des marqueurs. Idempotent : une deuxième
# exécution ne change rien (diff vide).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

README=README.md

# --- 0. instantané de latence (médiane des duration_s par script × OS) ------
# Calculé depuis `git show origin/data:data/runs.tsv`, événements de run
# COMPLET sur runners hébergés uniquement (schedule + push + workflow_dispatch ;
# pull_request est exclu à la source par le job `record`, donc absent du TSV).
# Format : script <TAB> os <TAB> médiane_secondes <TAB> n.
# n = nombre de mesures agrégées dans la cellule. Régénérer cet instantané en
# recalculant les médianes depuis la branche `data` puis en le recollant ici.
LAT_FACTS=$(cat <<'FACTS'
bb_hello.clj	ubuntu-latest	2	1
bb_hello.clj	macos-latest	8	1
cabal_hello.hs	ubuntu-latest	5	1
cabal_hello.hs	macos-latest	12	1
deno_hello.ts	ubuntu-latest	1	1
deno_hello.ts	macos-latest	0	1
nix_hello.el	ubuntu-latest	12	1
nix_hello.el	macos-latest	15	1
nix_hello.hs	ubuntu-latest	39	1
nix_hello.hs	macos-latest	48	1
nix_hello.perl	ubuntu-latest	2	1
nix_hello.perl	macos-latest	4	1
nix_hello.py	ubuntu-latest	3	1
nix_hello.py	macos-latest	7	1
nix_hello.rb	ubuntu-latest	2	1
nix_hello.rb	macos-latest	4	1
nixflake_hello.py	ubuntu-latest	1	1
nixflake_hello.py	macos-latest	1	1
nixflake_hello.rb	ubuntu-latest	1	1
nixflake_hello.rb	macos-latest	1	1
rust_hello.rs	ubuntu-latest	3	1
rust_hello.rs	macos-latest	7	1
scala_hello.scala	ubuntu-latest	36	1
scala_hello.scala	macos-latest	49	1
stack_hello_InStackage.hs	ubuntu-latest	1091	1
stack_hello_InStackage.hs	macos-latest	2	1
stack_hello_NotInStackage.hs	ubuntu-latest	99	1
stack_hello_NotInStackage.hs	macos-latest	2	1
uv_hello.py	ubuntu-latest	0	1
uv_hello.py	macos-latest	1	1
FACTS
)

latency_cell() {
  local script="$1" os="$2" cell
  cell=$(printf '%s\n' "$LAT_FACTS" \
    | awk -F'\t' -v s="$script" -v o="$os" '$1==s && $2==o { print $3 " (n=" $4 ")"; exit }')
  [[ -n "$cell" ]] && echo "$cell" || echo "—"
}

# --- 1. lire la table des scripts depuis check.sh -------------------------
# Une entrée par ligne "name|class|arg" à l'intérieur du bloc SCRIPTS=( ... ).
mapfile -t SCRIPT_ENTRIES < <(awk '
  /^SCRIPTS=\(/ { in_block=1; next }
  in_block && /^\)/ { in_block=0; next }
  in_block {
    line=$0
    gsub(/^[ \t]*"/, "", line)
    gsub(/"[ \t]*,?[ \t]*$/, "", line)
    if (line != "") print line
  }
' check.sh)

# --- 2. langage déduit de l'extension --------------------------------------
language_of() {
  case "$1" in
    *.hs)   echo "Haskell" ;;
    *.py)   echo "Python" ;;
    *.rb)   echo "Ruby" ;;
    *.el)   echo "Emacs Lisp" ;;
    *.perl) echo "Perl" ;;
    *.ts)   echo "TypeScript" ;;
    *.clj)  echo "Clojure" ;;
    *.rs)   echo "Rust" ;;
    *.scala) echo "Scala" ;;
    *)      echo "?" ;;
  esac
}

# --- 3. mécanisme déduit de la première ligne (le shebang) -----------------
mechanism_of() {
  local file="$1" first
  first=$(head -n1 "$file")
  case "$first" in
    *"env nix-shell") echo "nix-shell shebang" ;;
    *"env nix")        echo "native nix shebang (flake)" ;;
    *"env stack")      echo "stack script" ;;
    *"env cabal")      echo "cabal script" ;;
    *"uv run --script") echo "uv (PEP 723)" ;;
    *"deno run"*)      echo "deno" ;;
    *"env bb")         echo "babashka" ;;
    *"env rust-script") echo "rust-script" ;;
    *"scala-cli shebang") echo "scala-cli" ;;
    *)                 echo "?" ;;
  esac
}

# --- 4. pin extrait de la ligne de pin elle-même, par mécanisme ------------
pin_of() {
  local file="$1" mech="$2" line hash rev cs deps ver pkg
  case "$mech" in
    "nix-shell shebang"|"native nix shebang (flake)")
      # scoper la recherche du hash à la ligne qui pin nixpkgs : d'autres
      # lignes du header (ex. fetchTarball d'un paquet override) peuvent
      # contenir un autre hash de 40 caractères hexadécimaux.
      line=$(grep -E 'nixpkgs[=/]' "$file" | head -n1)
      hash=$(grep -oE '[0-9a-f]{40}' <<< "$line" | head -n1)
      if [[ -n "$hash" ]]; then
        echo "nixpkgs@${hash:0:12}"
      else
        echo "?"
      fi
      ;;
    "stack script")
      rev=$(grep -oE -- '--resolver [^ ]+' "$file" | head -n1 | sed 's/--resolver //')
      echo "resolver ${rev}"
      ;;
    "cabal script")
      cs=$(grep -oE '^index-state:.*' "$file" | head -n1 | sed 's/index-state: *//')
      ver=$(grep -oE '^with-compiler:.*' "$file" | head -n1 | sed 's/with-compiler: *//')
      echo "index-state ${cs}, ${ver}"
      ;;
    "uv (PEP 723)")
      deps=$(sed -n '/dependencies = \[/,/\]/p' "$file" | grep -oE '"[^"]+"' | tr -d '"' | paste -sd, -)
      echo "PEP 723: ${deps}"
      ;;
    deno)
      pkg=$(grep -oE 'npm:[^"]+' "$file" | head -n1)
      echo "import ${pkg}"
      ;;
    babashka)
      pkg=$(grep -oE '[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+ \{:mvn/version "[^"]+"\}' "$file" | head -n1 \
        | sed -E 's/ \{:mvn\/version "([^"]+)"\}/ @\1/')
      echo "deps.edn runtime: ${pkg}"
      ;;
    rust-script)
      line=$(grep -oE '^//! [A-Za-z0-9_.-]+ = "[^"]+"' "$file" | head -n1)
      pkg=$(sed -E 's#^//! ([A-Za-z0-9_.-]+) = "=?([^"]+)"#\1@\2#' <<< "$line")
      echo "Cargo.toml: ${pkg}"
      ;;
    scala-cli)
      pkg=$(grep -oE '^//> using dep .*' "$file" | head -n1 | sed 's#^//> using dep ##')
      echo "using dep: ${pkg}"
      ;;
    *)
      echo "?"
      ;;
  esac
}

# --- 6. Table A — host-residue matrix (source of truth: this heredoc) ------
# Verified cell by cell (tool docs + CI behaviour + docs/journal.md).
# No cell contains a literal "|" (would break the markdown table).
RESIDUE_ROWS=$(cat <<'ROWS'
| `nix-shell` shebang | `nix` (store + daemon) | full closure by nixpkgs hash: interpreter, packages, system libs | the `nix` binary; store/daemon; network to the substituter on first run |
| native `nix` shebang (flake) | `nix` ≥ 2.19, `nix-command` + `flakes` enabled | same: full closure by nixpkgs hash | `nix` ≥ 2.19 with those features; store/daemon; network on first run |
| `stack` script | `stack`; C toolchain/linker | GHC + Stackage snapshot (exact versions) via `--resolver lts-24.50` | the `stack` binary; host C toolchain/linker; Hackage/Stackage reachable |
| `cabal` script | `cabal`; `ghc-9.10.3` on PATH; C toolchain/linker | `index-state` + named compiler (`with-compiler: ghc-9.10.3`) | `cabal` **and** a GHC of the exact name — cabal does not provision it (largest residue of the three Haskell); populated Hackage index |
| `uv` (PEP 723) | `uv` | exact packages (`prettytable==3.16.0`) | the `uv` binary; exact Python version floats in `requires-python >=3.12` (uv fetches a managed Python if absent); PyPI reachable |
| `deno` | `deno` | direct imports at exact version (`npm:is-odd@3.0.1`) | the `deno` binary and version; npm/jsr reachable on first run |
| `babashka` | `bb` | Maven deps at exact version (`math.numeric-tower 0.1.0`) | the `bb` binary — its built-in library set is frozen by version (cheshire is bundled); Maven Central reachable for the added dep |
| `rust-script` | `rust-script`; `rustc`/`cargo`; linker | crates at exact version (`num-integer =0.1.46`) | the whole Rust toolchain (`rustc`/`cargo`, floating); host linker; crates.io reachable |
| `scala-cli` | `scala-cli` | Scala version (`//> using scala 3.8.3`) + deps (`upickle:4.1.0`) | the `scala-cli` binary — it fetches its JVM via coursier if absent (JVM version not pinned); Maven Central reachable |
ROWS
)

residue=""
residue+="| Mechanism | Host prerequisite | Pinned | Not pinned (residue) |"$'\n'
residue+="|---|---|---|---|"$'\n'
residue+="$RESIDUE_ROWS"$'\n'

# --- 7. Table B — specimens + median CI latency ----------------------------
rows=""
rows+="| Script | Language | Mechanism | Pins | CI median s (Ubuntu / macOS) |"$'\n'
rows+="|---|---|---|---|---|"$'\n'

for entry in "${SCRIPT_ENTRIES[@]}"; do
  IFS='|' read -r name class arg <<< "$entry"
  [[ -f "$name" ]] || { echo "generate-readme.sh: $name absent (déclaré dans check.sh)" >&2; exit 1; }

  lang=$(language_of "$name")
  mech=$(mechanism_of "$name")
  pin=$(pin_of "$name" "$mech")
  lat_ubuntu=$(latency_cell "$name" ubuntu-latest)
  lat_macos=$(latency_cell "$name" macos-latest)

  rows+="| \`$name\` | $lang | $mech | $pin | ${lat_ubuntu% (n=*} / ${lat_macos% (n=*} |"$'\n'
done

# --- 8. remplacement entre marqueurs, préservant le reste du README ---------
# (pas d'awk -v multi-lignes : peu portable ; découpage par numéro de ligne.
#  La fonction relit le fichier à chaque appel : les décalages de lignes du
#  premier remplacement n'affectent pas le second.)
replace_between() {
  local begin="$1" end="$2" content="$3" file="$4" bl el
  bl=$(grep -nF "$begin" "$file" | head -n1 | cut -d: -f1)
  el=$(grep -nF "$end" "$file" | head -n1 | cut -d: -f1)
  [[ -n "$bl" && -n "$el" ]] || {
    echo "generate-readme.sh: marqueurs $begin / $end absents de $file" >&2
    exit 1
  }
  {
    head -n "$bl" "$file"
    printf '%s' "$content"
    tail -n "+$el" "$file"
  } > "$file.tmp"
  mv "$file.tmp" "$file"
}

replace_between '<!-- BEGIN GENERATED RESIDUE -->' '<!-- END GENERATED RESIDUE -->' "$residue" "$README"
replace_between '<!-- BEGIN GENERATED MATRIX -->' '<!-- END GENERATED MATRIX -->' "$rows" "$README"
