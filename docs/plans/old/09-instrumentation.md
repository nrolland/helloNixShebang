# Plan 09 — Instrumentation : série temporelle et auto-signalement

## Contexte

L'instrument mesure déjà (verdicts, durées, par OS) mais jette la mesure à
chaque run, et un badge rouge hebdomadaire que personne ne regarde n'est pas
un signalement. Ce plan : (a) conserve chaque mesure dans une série
temporelle append-only sur une branche `data` ; (b) transforme un échec du
cron en issue GitHub nommée et datée — l'événement de pourriture devient un
objet de première classe.

## Préconditions

Plan 08 mergé.

## Contrat

### 1. Objectif décidable

- `./check.sh` émet, en plus du flux humain, `logs/verdicts.tsv` :
  une ligne par script `script<TAB>verdict<TAB>duration_s`.
- Un job `record` dans check.yml (après les deux jambes, `needs: check`,
  s'exécute même si une jambe a échoué — c'est là qu'il est le plus utile)
  appende à `data/runs.tsv` sur la branche `data` une ligne par
  script × OS : `utc_date<TAB>sha<TAB>event<TAB>os<TAB>script<TAB>verdict<TAB>duration_s<TAB>run_id`.
  Conditions : `schedule`, `push` sur master, `workflow_dispatch` — PAS les
  runs de PR (bruit).
- Sur `schedule` (et `workflow_dispatch`, pour testabilité) : pour chaque
  FAIL/TIMEOUT, une issue labellisée `rot`, titre
  `rot: <script> <verdict> (<os>)` ; si une issue `rot` ouverte existe déjà
  pour ce script, commenter au lieu de dupliquer. Corps : verdict, OS, date,
  lien du run, extrait du log du script (≤ 30 lignes).
- Vérifié réellement : un `workflow_dispatch` déclenché sur la branche du
  plan montre des lignes appendées sur `data` ; la logique d'issue est
  testée localement sur un `logs/verdicts.tsv` fabriqué (voir moyens).
- Branche `plan-09-instrumentation` poussée, PR ouverte, PAS de merge, PAS
  d'attente de CI au-delà du dispatch de test.

### 2. Périmètre fermé

Autorisés : `check.sh` (émission du TSV uniquement — ne pas toucher aux
oracles ni au retry), `.github/workflows/check.yml` (upload des verdicts en
artefact par jambe — toujours, pas seulement sur échec — et job `record`),
un script `record/` ou `.github/scripts/` si la logique d'issue mérite un
fichier testable localement (recommandé : la logique en script shell testé
hors CI, le YAML ne fait que l'appeler), branche `data` (créée orpheline si
absente, `data/runs.tsv` avec ligne d'en-tête), `docs/journal.md` (append).
Rien d'autre.

### 3. Moyens

- Le job `record` est l'unique écrivain de la branche `data` (un seul job,
  après les deux jambes → pas de course entre OS). En cas de push rejeté
  (course avec un autre run) : `git pull --rebase` puis re-push, 3
  tentatives.
- `permissions:` explicites au niveau du job : `contents: write`,
  `issues: write`. Créer le label `rot` s'il n'existe pas (`gh label create
  rot … || true`).
- Testabilité sans casser la CI : la logique d'issue vit dans un script
  appelable avec un TSV en argument — le tester localement avec un TSV
  fabriqué contenant un FAIL, en mode dry-run (`echo` des commandes gh) ;
  ne PAS créer de vraie issue de test, ou la fermer immédiatement en la
  marquant test si une vérification de bout en bout s'avère indispensable.
- `date -u`, jamais d'heure locale dans les données.
- Interdits : réécrire l'historique de `data`, toucher aux verdicts
  eux-mêmes, `continue-on-error` sur les jambes, merge.

### 4. Journal

Entrée datée : schéma du TSV et raisons, choix d'orchestration du job
`record`, pièges rencontrés (artefacts entre jobs, permissions, course sur
`data`).

### 5. Compte-rendu contraint

(a) schéma exact de `data/runs.tsv` + premières lignes réelles appendées
par le dispatch de test ; (b) logique d'issue (fichier, déclencheurs,
dédoublonnage) et sortie du test local dry-run ; (c) diff de check.yml en
résumé ; (d) entrées journal ; (e) URL de la PR. Puis fin de tour.
