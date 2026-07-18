# Vue d'ensemble — cycle 2 : de la collection à l'instrument

Recadrage acté : le dépôt n'est pas une collection d'exemples mais un
**instrument de mesure longitudinal de la durabilité des mécanismes de
scripts autosuffisants**. Chaque script est un spécimen ; le cron
hebdomadaire est l'échantillonnage ; les événements de pourriture (canal
EOL, redirection https, bug de kind jamais corrigé, httpbin instable,
bash 3.2…) sont le produit principal, consigné dans `docs/journal.md`.

Lecture typée complémentaire : chaque mécanisme est un **contrat** entre le
fichier distribué et l'environnement d'exécution ; la comparaison qui compte
est **ce qui n'est pas épinglé** — le résidu supposé de l'hôte (trilemme
dynamisme / garantie statique / coût : chaque mécanisme optimise deux
sommets et paie le troisième).

## Ordre d'exécution (strict) et attribution des modèles

| # | Plan | Dépend de | Agent | Livrable |
|---|------|-----------|-------|----------|
| 08 | [08-payload-reifie](08-payload-reifie.md) | — | **Sonnet** | scripts = header ⊕ payload, générés, garde de fraîcheur |
| 09 | [09-instrumentation](09-instrumentation.md) | 08 | **Sonnet** | série temporelle (branche `data`) + auto-issues de pourriture |
| 10 | [10-readme-instrument](10-readme-instrument.md) | 09 | **Opus** | README réorganisé : anatomie, résidu hôte, latences mesurées |

Attribution : 08 et 09 sont du jugement local borné par une spec précise
(Sonnet) ; 10 demande de la fidélité analytique (table des résidus, prose
du recadrage, honnêteté statistique sur des données rares) — Opus.

## État hérité du cycle 1 (PRs #2–#10, toutes mergées)

15 scripts × 9 mécanismes × 2 OS (ubuntu-latest, macos-latest ARM64), tous
PASS. Harnais `./check.sh [script]` : verdicts en flux, retry ×3 pour les
oracles à service externe, `KNOWN_FAILING` (vide) + `known-failing.local`
(gitignoré, spécificités machine), logs dans `logs/`, `TIMEOUT_S=1200`,
idiome bash-3.2-compatible pour les tableaux vides sous `set -u`.
CI `.github/workflows/check.yml` : matrice 2 OS `fail-fast: false`,
`timeout-minutes: 120`, Determinate nix-installer + magic-nix-cache,
haskell-actions/setup GHC 9.10.3, caches `~/.stack` par OS, outils via
`nix profile add` pinné `nixpkgs@4382ed2b7a6839d4280a9b386db49cbc5907414d`
ou actions épinglées, coreutils nix sur macOS (GNU `timeout`), garde de
fraîcheur README sur la jambe Linux, artefacts `logs-<os>` sur échec, cron
hebdo + badge. README généré par `./generate-readme.sh` (section entre
marqueurs `BEGIN/END GENERATED MATRIX`). Pins : Stackage lts-24.50
(GHC 9.10.3) ; `type-level-sets` via commit git e1ac77f (fix de kind non
publié sur Hackage). Journal d'atelier : `docs/journal.md` (append-only,
entrées datées).

## Protocole de supervision (session principale)

- Une branche par plan (`plan-08-payload`, …), agents lancés en arrière-plan
  dans CE checkout (pas de worktree), séquentiellement (périmètres se
  recouvrant sur check.sh/check.yml).
- **Les agents ne mergent pas.** Contrat : travail local vérifié → push →
  PR ouverte → compte-rendu contraint → fin de tour, sans attendre la CI.
- La session surveille la CI elle-même :
  `gh run watch <id> --exit-status --interval 30 > <scratchpad>/…log 2>&1 && echo CI_GREEN || echo CI_RED`
  en tâche de fond ; **merge conditionné au verdict explicite CI_GREEN**,
  jamais au succès d'une commande de lecture. Merge méthode merge (pas
  squash), branches conservées.
- Après merge : `git pull --rebase origin master`, vérifier `git status` propre.
- Sonnet s'arrête parfois en attente passive malgré les consignes ; si un
  agent termine avec du travail non poussé ou une CI non conclue, le
  relancer via SendMessage avec un ré-ancrage réel (`git status`,
  `git log --oneline -3`) et l'étape précise restante.
- Interruptions API transitoires (ENOTFOUND, stream idle timeout) : relancer
  l'agent dans son contexte, même ré-ancrage.

## Conventions communes aux plans (contrat à cinq clauses)

Chaque prompt de délégation reprend : (1) objectif décidable — commandes de
vérification et état final exigé ; (2) périmètre fermé — liste des fichiers
autorisés, rien d'autre ; (3) moyens autorisés et interdits explicites —
jamais d'affaiblissement d'oracle, pas de merge ; (4) journal —
difficultés non triviales dans `docs/journal.md`, entrée datée ;
(5) compte-rendu contraint — format bref imposé.

## Critère de fin du cycle

`./assemble-scripts.sh` et `./generate-readme.sh` idempotents et gardés en
CI ; les 15 scripts byte-identiques à leur assemblage header ⊕ payload ;
chaque run planifié ou push master appende ses verdicts+durées à la branche
`data` ; un échec du cron ouvre ou alimente une issue `rot` ; le README
donne l'anatomie, le résidu non-épinglé par mécanisme et les latences
mesurées ; les plans 08–10 archivés dans `docs/plans/old/`.
