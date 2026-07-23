#!/usr/bin/env bash
# Auto-signalement de pourriture (plan 09) : l'événement d'échec du cron
# devient un objet de première classe — une issue GitHub nommée et datée.
#
# Pour chaque script FAIL/TIMEOUT (sur l'une ou l'autre jambe), ouvre une
# issue labellisée `rot` de titre « rot: <script> <verdict> (<os>) ». Si une
# issue `rot` OUVERTE existe déjà pour ce script (dédoublonnage par script,
# tous OS/verdicts confondus), on COMMENTE au lieu de dupliquer.
#
# Usage : rot-issues.sh <artifacts-root>
#   <artifacts-root> contient logs-<os>/verdicts.tsv (script, verdict,
#   duration_s) et logs-<os>/<script>.log (pour l'extrait de log).
#
# Env :
#   GH_TOKEN            jeton avec issues:write
#   GITHUB_SERVER_URL   (déf. https://github.com)
#   GITHUB_REPOSITORY   owner/repo
#   GITHUB_RUN_ID       identifiant du run (→ lien)
#   DRY_RUN=1           n'exécute pas gh : écho des commandes (test local).
set -euo pipefail

ROOT="${1:?usage: rot-issues.sh <artifacts-root>}"
DRY_RUN="${DRY_RUN:-0}"

server="${GITHUB_SERVER_URL:-https://github.com}"
repo="${GITHUB_REPOSITORY:-owner/repo}"
run_id="${GITHUB_RUN_ID:-0}"
run_url="${server}/${repo}/actions/runs/${run_id}"
today=$(date -u +%Y-%m-%d)

# Écho des commandes gh en dry-run (avec quoting sûr), exécution sinon.
gh_run() {
  if [ "$DRY_RUN" = "1" ]; then
    printf 'DRY-RUN gh'; printf ' %q' "$@"; printf '\n'
  else
    gh "$@"
  fi
}

# Label `rot` créé au besoin (idempotent — || true si déjà présent).
gh_run label create rot \
  --color b60205 \
  --description "spécimen en pourriture (échec constaté par le cron)" || true

for dir in "$ROOT"/logs-*/; do
  [ -d "$dir" ] || continue
  os=$(basename "$dir"); os=${os#logs-}
  vf="$dir/verdicts.tsv"
  [ -f "$vf" ] || continue

  while IFS=$'\t' read -r script verdict duration; do
    [ -z "${script:-}" ] && continue
    case "$verdict" in
      FAIL|TIMEOUT) ;;
      *) continue ;;
    esac

    title="rot: ${script} ${verdict} (${os})"

    logfile="$dir/${script}.log"
    if [ -f "$logfile" ]; then
      excerpt=$(tail -n 30 "$logfile")
    else
      excerpt="(log indisponible)"
    fi

    body=$(printf '**verdict** %s\n**OS** %s\n**date** %s\n**run** %s\n\n```\n%s\n```\n' \
      "$verdict" "$os" "$today" "$run_url" "$excerpt")

    # Une issue `rot` ouverte existe-t-elle déjà pour CE script ? (dédoublonnage
    # par script — un même spécimen ne génère qu'une issue, même s'il pourrit
    # sur les deux OS ou change de verdict.) En dry-run on ne consulte pas
    # l'API : on montre le chemin de création.
    existing=""
    if [ "$DRY_RUN" != "1" ]; then
      existing=$(gh issue list --label rot --state open --json number,title \
        --jq ".[] | select(.title | startswith(\"rot: ${script} \")) | .number" \
        | head -n1)
    fi

    if [ -n "$existing" ]; then
      echo "rot: issue #$existing déjà ouverte pour $script → commentaire"
      gh_run issue comment "$existing" --body "$body"
    else
      echo "rot: nouvelle issue pour $script ($verdict, $os)"
      gh_run issue create --title "$title" --label rot --body "$body"
    fi
  done < "$vf"
done
