#!/usr/bin/env bash
# Append-only de la série temporelle sur la branche orpheline `data` (plan 09).
#
# UNIQUE écrivain de la branche `data` : appelé une seule fois par le job
# `record` de la CI, APRÈS les deux jambes de la matrice — donc pas de course
# entre OS au sein d'un run. La seule course résiduelle est inter-runs (deux
# runs `record` concurrents) : traitée par re-fetch + re-append + re-push,
# 3 tentatives. Chaque tentative repart d'un clone frais de l'état distant et
# n'appende les lignes qu'une fois → un push rejeté ne duplique jamais.
#
# Usage : append-runs.sh <artifacts-root>
#   <artifacts-root> contient un sous-dossier logs-<os>/ par jambe, chacun
#   avec un verdicts.tsv (colonnes : script, verdict, duration_s) produit par
#   check.sh et remonté en artefact.
#
# Env attendu (fourni par GitHub Actions) :
#   GITHUB_REPOSITORY  owner/repo
#   GITHUB_SHA         sha du commit vérifié
#   GITHUB_EVENT_NAME  schedule | push | workflow_dispatch
#   GITHUB_RUN_ID      identifiant du run (→ lien)
#   GH_TOKEN           jeton avec contents:write (push de la branche data)
set -euo pipefail

ROOT="${1:?usage: append-runs.sh <artifacts-root>}"

# En-tête de data/runs.tsv : une ligne par script × OS.
HEADER=$'utc_date\tsha\tevent\tos\tscript\tverdict\tduration_s\trun_id'

# Horodatage UTC unique pour toutes les lignes de CE run (jamais d'heure
# locale dans les données — voir plan 09 §3).
utc_date=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# --- construction des lignes (une fois, avant la boucle de push) -----------
rows=$(mktemp)
found=0
for dir in "$ROOT"/logs-*/; do
  [ -d "$dir" ] || continue
  os=$(basename "$dir"); os=${os#logs-}
  vf="$dir/verdicts.tsv"
  [ -f "$vf" ] || continue
  while IFS=$'\t' read -r script verdict duration; do
    [ -z "${script:-}" ] && continue
    found=1
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$utc_date" "$GITHUB_SHA" "$GITHUB_EVENT_NAME" "$os" \
      "$script" "$verdict" "$duration" "$GITHUB_RUN_ID" >> "$rows"
  done < "$vf"
done

if [ "$found" -eq 0 ]; then
  echo "append-runs: aucun verdicts.tsv trouvé sous $ROOT — rien à appender" >&2
  exit 1
fi

echo "append-runs: $(wc -l < "$rows") lignes à appender"

# --- push avec re-fetch/rebase, 3 tentatives -------------------------------
remote="https://x-access-token:${GH_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"

for attempt in 1 2 3; do
  work=$(mktemp -d)
  (
    cd "$work"
    git init -q
    git remote add origin "$remote"
    git config user.name  "github-actions[bot]"
    git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

    # Repartir de l'état distant frais à chaque tentative (orpheline si
    # absente). Un push rejeté par une course inter-runs est absorbé ici :
    # on récupère le nouveau sommet et on ré-appende les mêmes lignes.
    if git fetch -q --depth 1 origin data 2>/dev/null; then
      git checkout -q -B data FETCH_HEAD
    else
      git checkout -q --orphan data
    fi

    mkdir -p data
    [ -f data/runs.tsv ] || printf '%s\n' "$HEADER" > data/runs.tsv
    cat "$rows" >> data/runs.tsv

    git add data/runs.tsv
    git commit -q -m "record: run ${GITHUB_RUN_ID} (${GITHUB_EVENT_NAME})"
    git push -q origin HEAD:data
  ) && { echo "append-runs: poussé sur data (tentative $attempt)"; exit 0; }
  echo "append-runs: push rejeté ou échec (tentative $attempt), re-fetch…" >&2
  sleep $((attempt * 3))
done

echo "append-runs: échec du push après 3 tentatives" >&2
exit 1
