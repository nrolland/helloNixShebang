#!/usr/bin/env bash
# Harnais de vérification — voir docs/plans/02-harnais-ci.md
#
# Exécute chaque script du dépôt et vérifie sa sortie contre un oracle.
# Verdicts émis en flux (un par script, à la fin de son exécution) :
#   PASS    — script exécuté, oracle satisfait.
#   FAIL    — script exécuté, oracle non satisfait, pas dans KNOWN_FAILING.
#   XFAIL   — script dans KNOWN_FAILING, oracle non satisfait (attendu).
#   XPASS   — script dans KNOWN_FAILING mais l'oracle est satisfait quand
#             même (signal : la liste peut être allégée, cf. plan 03).
#   TIMEOUT — le script n'a pas terminé sous TIMEOUT_S secondes.
#
# Code de sortie global : 0 ssi aucun FAIL et aucun TIMEOUT (hors XFAIL/XPASS).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

TIMEOUT_S=1200
LOG_DIR=logs
mkdir -p "$LOG_DIR"

# --- table des scripts et de leur classe d'oracle -------------------------
# format : "script|classe|argument"
#   diff_stdout|<fichier expected>       stdout == fichier (diff exact)
#   diff_stderr|<fichier expected>       stderr, filtré du bruit nix-shell,
#                                        == fichier (diff exact)
#   exit0_nonempty_stdout|-              exit 0 ET stdout non vide (réseau)
#   exit0_stdout_contains|<sous-chaîne>  exit 0 ET stdout contient la
#                                        sous-chaîne (réseau)
#   exit0_stderr_contains|<sous-chaîne>  exit 0 ET stderr contient la
#                                        sous-chaîne (build depuis les
#                                        sources parfois, bruit nix-shell
#                                        trop variable pour un diff exact)
SCRIPTS=(
  "nix_hello.hs|diff_stdout|expected/nix_hello.hs.out"
  "nix_hello.py|diff_stdout|expected/nix_hello.py.out"
  "nix_hello.rb|diff_stdout|expected/nix_hello.rb.out"
  "nix_hello.el|exit0_stderr_contains|Hi"
  "nix_hello.perl|exit0_nonempty_stdout|-"
  "nixflake_hello.rb|diff_stdout|expected/nixflake_hello.rb.out"
  "nixflake_hello.py|diff_stdout|expected/nixflake_hello.py.out"
  "stack_hello_NotInStackage.hs|diff_stdout|expected/stack_hello_NotInStackage.hs.out"
  "stack_hello_InStackage.hs|exit0_stdout_contains|The status code was: 200"
  "cabal_hello.hs|diff_stdout|expected/cabal_hello.hs.out"
  "uv_hello.py|diff_stdout|expected/nix_hello.py.out"
  "deno_hello.ts|diff_stdout|expected/deno_hello.ts.out"
  "bb_hello.clj|diff_stdout|expected/bb_hello.clj.out"
  "rust_hello.rs|diff_stdout|expected/rust_hello.rs.out"
  "scala_hello.scala|diff_stdout|expected/scala_hello.scala.out"
)

# --- scripts constatés cassés (le harnais les nomme, ne les masque pas) ---
# (vide depuis le plan 03 — voir docs/plans/03-pins-reifies.md)
KNOWN_FAILING=()

# Augmentation locale, jamais commitée (voir .gitignore) : un nom de script
# par ligne. Sert à documenter des échecs propres à CETTE machine sans les
# faire passer pour des échecs de script en CI, où le fichier est absent et
# le script tourne pour de vrai. CI fait foi. Vide depuis le plan 03 (le
# bump du résolveur stack vers lts-24.50 / GHC 9.10.3 a résolu l'échec
# d'installation GHC constaté sur ce Mac au plan 01 — voir known-failing.local
# pour l'historique).
LOCAL_KNOWN_FAILING_FILE=known-failing.local
if [[ -f "$LOCAL_KNOWN_FAILING_FILE" ]]; then
  while IFS= read -r line; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    KNOWN_FAILING+=("$line")
  done < "$LOCAL_KNOWN_FAILING_FILE"
fi

is_known_failing() {
  local name="$1" f
  for f in "${KNOWN_FAILING[@]}"; do
    [[ "$f" == "$name" ]] && return 0
  done
  return 1
}

# Bruit de nix-shell à retirer avant un diff_stderr (téléchargements,
# construction de dérivations, avertissement de dépréciation des channels,
# message de chargement du site-start.el injecté par emacsWithPackages —
# tous non-déterministes ou hors du contrôle du script lui-même).
filter_nix_noise() {
  grep -Ev '^(warning:|these [0-9]+ |  /nix/store|copying path|building |querying |Loading /nix/store)' || true
}

FILTER="${1:-}"

overall_exit=0
declare -a VERDICT_LINES=()

for entry in "${SCRIPTS[@]}"; do
  IFS='|' read -r name class arg <<< "$entry"

  if [[ -n "$FILTER" && "$name" != "$FILTER" ]]; then
    continue
  fi

  out_file=$(mktemp)
  err_file=$(mktemp)
  start=$(date +%s)
  set +e
  timeout "${TIMEOUT_S}s" "./$name" >"$out_file" 2>"$err_file"
  rc=$?
  set -e
  end=$(date +%s)
  duration=$((end - start))

  {
    echo "=== $name (exit=$rc, ${duration}s) ==="
    echo "--- stdout ---"
    cat "$out_file"
    echo "--- stderr ---"
    cat "$err_file"
  } > "$LOG_DIR/$name.log"

  ok=0
  if [[ $rc -eq 124 || $rc -eq 137 ]]; then
    verdict="TIMEOUT"
  else
    case "$class" in
      diff_stdout)
        if [[ $rc -eq 0 ]] && diff -q "$arg" "$out_file" >/dev/null 2>&1; then
          ok=1
        fi
        ;;
      diff_stderr)
        filtered=$(mktemp)
        filter_nix_noise < "$err_file" > "$filtered"
        if [[ $rc -eq 0 ]] && diff -q "$arg" "$filtered" >/dev/null 2>&1; then
          ok=1
        fi
        rm -f "$filtered"
        ;;
      exit0_nonempty_stdout)
        if [[ $rc -eq 0 && -s "$out_file" ]]; then
          ok=1
        fi
        ;;
      exit0_stdout_contains)
        if [[ $rc -eq 0 ]] && grep -qF "$arg" "$out_file"; then
          ok=1
        fi
        ;;
      exit0_stderr_contains)
        if [[ $rc -eq 0 ]] && grep -qF "$arg" "$err_file"; then
          ok=1
        fi
        ;;
      *)
        echo "classe d'oracle inconnue: $class" >&2
        exit 2
        ;;
    esac

    if [[ $ok -eq 1 ]]; then
      if is_known_failing "$name"; then
        verdict="XPASS"
      else
        verdict="PASS"
      fi
    else
      if is_known_failing "$name"; then
        verdict="XFAIL"
      else
        verdict="FAIL"
      fi
    fi
  fi

  rm -f "$out_file" "$err_file"

  printf '%-8s %-32s %ss\n' "$verdict" "$name" "$duration"
  VERDICT_LINES+=("$verdict $name")

  if [[ "$verdict" == "FAIL" || "$verdict" == "TIMEOUT" ]]; then
    overall_exit=1
  fi
done

exit "$overall_exit"
