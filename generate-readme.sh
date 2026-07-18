#!/usr/bin/env bash
# Génère la section matrice du README depuis les scripts du dépôt et la
# table SCRIPTS de check.sh (source unique de vérité). Voir
# docs/plans/05-readme-genere.md.
#
# Ne remplace que l'intérieur des marqueurs BEGIN/END GENERATED MATRIX.
# Idempotent : une deuxième exécution ne change rien (diff vide).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

README=README.md
BEGIN_MARK='<!-- BEGIN GENERATED MATRIX -->'
END_MARK='<!-- END GENERATED MATRIX -->'

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

# --- 6. construction de la table --------------------------------------------
rows=""
rows+="| Script | Langage | Mécanisme | Pin | Oracle |"$'\n'
rows+="|---|---|---|---|---|"$'\n'

for entry in "${SCRIPT_ENTRIES[@]}"; do
  IFS='|' read -r name class arg <<< "$entry"
  [[ -f "$name" ]] || { echo "generate-readme.sh: $name absent (déclaré dans check.sh)" >&2; exit 1; }

  lang=$(language_of "$name")
  mech=$(mechanism_of "$name")
  pin=$(pin_of "$name" "$mech")
  oracle=$(oracle_of "$class" "$arg")

  rows+="| \`$name\` | $lang | $mech | $pin | $oracle |"$'\n'
done

# --- 7. remplacement entre les marqueurs, préservant le reste du README ----
# (pas d'awk -v multi-lignes : peu portable ; découpage par numéro de ligne)
begin_line=$(grep -nF "$BEGIN_MARK" "$README" | head -n1 | cut -d: -f1)
end_line=$(grep -nF "$END_MARK" "$README" | head -n1 | cut -d: -f1)
[[ -n "$begin_line" && -n "$end_line" ]] || {
  echo "generate-readme.sh: marqueurs BEGIN/END absents de $README" >&2
  exit 1
}

{
  head -n "$begin_line" "$README"
  printf '%s' "$rows"
  tail -n "+$end_line" "$README"
} > "$README.tmp"

mv "$README.tmp" "$README"
