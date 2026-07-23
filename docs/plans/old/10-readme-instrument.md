# Plan 10 — README de l'instrument : anatomie, résidu hôte, latences mesurées

## Contexte

Le README actuel décrit une collection. Ce plan le réorganise autour de la
question du lecteur — « lequel choisir pour mon cas ? » — et du recadrage :
le dépôt est un instrument longitudinal ; la comparaison qui compte est le
**résidu non-épinglé** (ce que chaque mécanisme suppose encore de l'hôte) ;
les latences sont **mesurées** (données CI réelles), pas affirmées.

## Préconditions

Plans 08 et 09 mergés (structure headers/payloads en place ; `data/runs.tsv`
alimenté — encore peu de lignes, l'honnêteté statistique s'impose).

## Contrat

### 1. Objectif décidable

README réorganisé ainsi, dans l'ordre :
1. **Thèse** (3–5 phrases) : le recadrage tient en une phrase — **le contrat
   de runtime voyage avec le script** (« the runtime contract travels with
   the script »). Un script exécutable dépend normalement d'un environnement
   invisible ; ce dépôt rend cet environnement explicite *dans* le script.
   Ne PAS écrire « sans runtime » (une machine sans runtime n'exécute rien —
   l'affirmation est littéralement fausse) : chaque spécimen déclare comment
   obtenir son interpréteur et ses dépendances, et le cron hebdomadaire
   vérifie si un hôte Linux/macOS frais honore encore ce contrat. Instrument
   longitudinal, spécimens, échantillonnage hebdomadaire, le journal comme
   registre des événements de pourriture (lien vers `docs/journal.md`), badge
   existant conservé. Mentionner que `assemble-scripts.sh` (payload
   byte-identique) est le **contrôle expérimental** : les différences entre
   spécimens s'imputent au mécanisme, pas au programme.
2. **Anatomie d'un script** : UN script annoté ligne à ligne (header : le
   mécanisme et son pin ; payload : le programme partagé) — refléter la
   structure `headers/` ⊕ `payloads/` du plan 08.
3. **Table A — les mécanismes** (9 lignes, semi-statique, vérifiée) :
   mécanisme | prérequis hôte | ce qui est épinglé | **ce qui ne l'est pas**
   (résidu). Cette **matrice de résidus est la source de vérité unique** de
   la comparaison. Les quatre catégories de provisioning — (i) environnement
   complet (shebangs Nix), (ii) toolchain provisionné (stack, uv, scala-cli),
   (iii) runtime à dépendances inline (deno, babashka), (iv) wrapper autour
   d'une toolchain présente (cabal, rust-script) — n'apparaissent qu'en
   **prose de regroupement**, jamais comme partition primaire : plusieurs
   mécanismes débordent d'une seule case (uv provisionne l'interpréteur ET
   fait de l'inline ; babashka a un jeu de libs *gelé* dans son binaire, cf.
   journal). La matrice, elle, exprime ces recouvrements ; la taxonomie sert
   d'introduction, pas de vérité.
4. **Table B — les spécimens** (15 lignes, générée) : la table actuelle +
   colonne latence médiane par OS tirée de `data/runs.tsv`.
5. **Trois lignes de décision** (prose) : quel mécanisme selon le cas.
6. **Limits** (section d'honnêteté, obligatoire) : ce que le dépôt ne
   prétend PAS — pas de zéro-dépendance (le prérequis bootstrap reste), pas
   nécessairement hermétique (la CI préinstalle les toolchains ; un script
   pourrait utiliser un résidu non déclaré — la *preuve à hôte nu* qui
   mesurerait cette frontière est un travail futur, hors de ce plan), pas
   nécessairement offline (registres/cache au premier run). Renvoyer à la
   Table A pour le résidu par mécanisme.
7. L'invitation à PR et les liens historiques existants, conservés.

Décidable par : `./generate-readme.sh` idempotent (les deux gardes de
fraîcheur CI passent) ; chaque cellule de la table A vérifiée (voir moyens) ;
les latences portent leur effectif (`n=`) et proviennent réellement du TSV.
Branche `plan-10-readme-instrument` poussée, PR ouverte, PAS de merge.
Clôture du cycle dans la même PR : `git mv` de
`docs/plans/{00-overview-cycle2,08-payload-reifie,09-instrumentation,10-readme-instrument}.md`
vers `docs/plans/old/`.

### 2. Périmètre fermé

Autorisés : `README.md` (partie rédigée à la main + sections générées via
le générateur uniquement), `generate-readme.sh` (table B et injection des
latences ; la table A peut être générée depuis une table de faits dans le
script ou rédigée à la main entre ses propres marqueurs — au choix, mais une
seule source de vérité), `docs/journal.md` (append), `docs/plans/` (le
`git mv` de clôture). Rien d'autre — ni scripts, ni harnais, ni check.yml.

### 3. Moyens — et le contenu analytique attendu

**Table A (ébauche à VÉRIFIER cellule par cellule** contre la doc de
l'outil, le comportement observé en CI, et le journal — corriger ce qui ne
tient pas, ne rien publier d'invérifié) :

- **nix-shell shebang** (tarball nixpkgs par hash) — épingle : clôture
  complète (interpréteur, paquets, libs système). Résidu : le binaire `nix`
  et sa version ; le store/daemon ; réseau vers le cache au premier run.
- **nix shebang natif** — idem ; résidu : nix ≥ 2.19.
- **stack script** — épingle : GHC + ensemble Stackage (versions exactes).
  Résidu : binaire `stack` ; toolchain C/linker de l'hôte (constaté au plan
  01 : l'incident Xcode CLT) ; Hackage/Stackage joignables.
- **cabal script** — épingle : index-state + compilateur *nommé*. Résidu :
  binaire `cabal` ET un GHC du bon nom déjà sur l'hôte (constaté : échec
  local, PATH) — le plus grand résidu des trois Haskell.
- **uv / PEP 723** — épingle : paquets exacts (`==`) ; contraint
  l'interpréteur (`requires-python`) et peut le fournir (Python managé —
  vérifier ce point dans la doc uv). Résidu : binaire `uv` ; la version
  Python exacte flotte dans la contrainte.
- **deno** — épingle : imports directs (`npm:`/`jsr:` à version exacte).
  Résidu : binaire `deno` et sa version ; registres joignables.
- **babashka** — épingle : deps Maven à version exacte. Résidu : binaire
  `bb` — dont l'ensemble des bibliothèques *compilées en dur* dépend de sa
  version (constaté au plan 04 : cheshire bundlé).
- **rust-script** — épingle : crates (`=version`). Résidu : toute la
  toolchain (rustc/cargo flottants) ; linker hôte.
- **scala-cli** — épingle : version Scala (`//> using scala`) + deps.
  Résidu : binaire `scala-cli` (qui gère lui-même sa JVM — vérifier) ;
  Maven Central joignable.

**Latences (table B)** : médiane des `duration_s` par script × OS depuis
`data/runs.tsv`, événements `schedule` et `push` seulement, avec `n=` par
cellule. Si n < 3, afficher la valeur avec son n sans qualificatif de
stabilité. Ne PAS étiqueter froid/chaud (l'état du cache n'est pas dans les
données) — dire « durée en CI » et noter en légende que la première
exécution sans cache peut être bien plus lente (renvoyer au journal, qui a
les chiffres constatés : stack à froid 1028 s sur macOS).

**Prose** : registre précis, sans emphase ; pas de promesse sur l'avenir du
projet ; chaque affirmation factuelle doit être adossée au dépôt (journal,
données, code).

Interdits : inventer une cellule, copier l'ébauche sans vérification,
réécrire le journal, toucher aux scripts/harnais, merge.

### 4. Journal

Entrée datée : les cellules de l'ébauche corrigées après vérification (et
pourquoi), les choix d'implémentation du générateur (source de vérité de la
table A), l'état des données au moment de la génération (nombre de runs).

### 5. Compte-rendu contraint

(a) plan du README final (titres) ; (b) table A finale + liste des cellules
corrigées vs l'ébauche ; (c) extrait de la table B avec latences et n ;
(d) preuve d'idempotence des gardes ; (e) entrées journal ; (f) URL de la
PR. Puis fin de tour.
