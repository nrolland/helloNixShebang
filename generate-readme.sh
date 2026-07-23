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
    *"env nix")        echo "nix shebang natif (flake)" ;;
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
    "nix-shell shebang"|"nix shebang natif (flake)")
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

# --- 5. oracle déduit de la classe déclarée dans check.sh ------------------
oracle_of() {
  local class="$1" arg="$2"
  case "$class" in
    diff_stdout|diff_stderr)
      echo "fichier (\`$arg\`)" ;;
    exit0_nonempty_stdout)
      echo "réseau (stdout non vide)" ;;
    exit0_stdout_contains)
      echo "réseau (stdout contient « $arg »)" ;;
    exit0_stderr_contains)
      echo "réseau (stderr contient « $arg »)" ;;
    *)
      echo "?" ;;
  esac
}

# --- 6. Table A — matrice de résidus (source de vérité : ce heredoc) -------
# Vérifiée cellule par cellule (doc outil + comportement CI + docs/journal.md).
# Aucune cellule ne contient de « | » littéral (incompatible avec le markdown).
RESIDUE_ROWS=$(cat <<'ROWS'
| `nix-shell` shebang | `nix` (store + daemon) | clôture complète par hash nixpkgs : interpréteur, paquets, libs système | binaire `nix` et sa version ; store/daemon ; réseau vers le substituter au premier run |
| `nix` shebang natif (flake) | `nix` ≥ 2.19, features `nix-command` + `flakes` activées | idem : clôture complète par hash nixpkgs | binaire `nix` ≥ 2.19 avec `nix-command`/`flakes` ; store/daemon ; réseau au premier run |
| `stack` script | `stack` ; toolchain C/linker | GHC + snapshot Stackage (versions exactes) via `--resolver lts-24.50` | binaire `stack` ; toolchain C/linker de l'hôte (incident Xcode CLT, plan 01) ; Hackage/Stackage et le tarball extra-dep joignables |
| `cabal` script | `cabal` ; `ghc-9.10.3` sur le PATH ; toolchain C/linker | `index-state` + compilateur nommé (`with-compiler: ghc-9.10.3`) | binaire `cabal` ET un GHC du nom exact déjà présent — cabal ne le provisionne pas (échec local PATH, journal) ; index Hackage peuplé ; toolchain C/linker. Le plus grand résidu des trois Haskell |
| `uv` (PEP 723) | `uv` | paquets exacts (`prettytable==3.16.0`) | binaire `uv` ; la version exacte de Python flotte dans `requires-python >=3.12` (uv télécharge un Python managé si absent) ; PyPI joignable |
| `deno` | `deno` | imports directs à version exacte (`npm:is-odd@3.0.1`) | binaire `deno` et sa version ; registres (npm/jsr) joignables au premier run |
| `babashka` | `bb` | deps Maven à version exacte (`math.numeric-tower 0.1.0`) | binaire `bb`, dont le jeu de bibliothèques compilées en dur dépend de la version (cheshire bundlé, plan 04) ; Maven Central joignable pour la dep ajoutée |
| `rust-script` | `rust-script` ; `rustc`/`cargo` ; linker | crates à version exacte (`num-integer =0.1.46`) | toute la toolchain Rust (`rustc`/`cargo`, versions flottantes) ; linker de l'hôte ; crates.io joignable |
| `scala-cli` | `scala-cli` | version Scala (`//> using scala 3.8.3`) + deps (`upickle:4.1.0`) | binaire `scala-cli` — il télécharge sa JVM via coursier si absente (version de JVM non épinglée dans le script) ; Maven Central joignable |
ROWS
)

residue=""
residue+="| Mécanisme | Prérequis hôte | Épinglé | Résidu non épinglé |"$'\n'
residue+="|---|---|---|---|"$'\n'
residue+="$RESIDUE_ROWS"$'\n'

# --- 7. Table B — spécimens + latences médianes par OS ----------------------
rows=""
rows+="| Script | Langage | Mécanisme | Pin | Oracle | Ubuntu médiane (s) | macOS médiane (s) |"$'\n'
rows+="|---|---|---|---|---|---|---|"$'\n'

for entry in "${SCRIPT_ENTRIES[@]}"; do
  IFS='|' read -r name class arg <<< "$entry"
  [[ -f "$name" ]] || { echo "generate-readme.sh: $name absent (déclaré dans check.sh)" >&2; exit 1; }

  lang=$(language_of "$name")
  mech=$(mechanism_of "$name")
  pin=$(pin_of "$name" "$mech")
  oracle=$(oracle_of "$class" "$arg")
  lat_ubuntu=$(latency_cell "$name" ubuntu-latest)
  lat_macos=$(latency_cell "$name" macos-latest)

  rows+="| \`$name\` | $lang | $mech | $pin | $oracle | $lat_ubuntu | $lat_macos |"$'\n'
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
