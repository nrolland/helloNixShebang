# Plan 11 — La preuve à hôte nu : du résidu affirmé au résidu mesuré

## Contexte

Le cycle 08–10 a rendu le résidu hôte **explicite** (Table A du README) mais
il reste **affirmé**, pas **mesuré**. La CI actuelle installe toutes les
toolchains (GHC, deno, babashka, rust-script, scala-cli, uv) *puis* lance les
scripts : elle prouve que les déclarations de dépendances **résolvent**, pas
qu'un spécimen **provisionne ce qu'il prétend depuis un hôte nu**. Un script
pourrait utiliser en douce un binaire déjà présent sur le PATH du runner sans
qu'on le voie — la frontière du contrat n'est pas testée.

Ce plan ajoute des jobs Linux **isolés par mécanisme**, chacun démarrant d'un
conteneur minimal ne contenant **que le prérequis bootstrap déclaré** (la
colonne « prérequis hôte » de la Table A, qui devient ainsi la spécification
exécutable du test). Un job qui PASSE **vérifie** la ligne de résidu ; un job
qui ÉCHOUE **falsifie** l'affirmation (résidu non déclaré utilisé) — c'est un
constat, routé vers la même machinerie `rot`/journal que la pourriture
temporelle.

Lecture unifiée : l'observatoire mesure désormais **deux axes de
décomposition** — la **durée** (le contrat pourrit-il dans le temps ? cron
hebdo) et la **minimalité** (le contrat utilise-t-il un résidu non déclaré ?
hôte nu). Deux détecteurs, une seule série, un seul canal de signalement.

## Préconditions

Cycle 08–10 mergé : `headers/` ⊕ `payloads/`, branche `data`, README avec la
matrice de résidus (Table A) — dont la colonne « prérequis hôte » sert de
table de correspondance mécanisme → prérequis.

## Contrat

### 1. Objectif décidable

- Un workflow `.github/workflows/clean-host.yml` (séparé de `check.yml` — la
  matrice 2-OS existante ne bouge pas ; macOS reste le test de portabilité
  sur hôte réaliste, non conteneurisable sur runners GitHub).
- Un job par **famille de mécanisme**, `runs-on: ubuntu-latest`,
  `container: debian:bookworm-slim` (ou image de base équivalente, minimale
  et épinglée par digest), installant **exactement un** prérequis bootstrap
  déclaré, puis lançant ses spécimens via `./check.sh <script>`.
- Correspondance mécanisme → prérequis dérivée de la Table A (source de
  vérité unique ; toute divergence entre le job et la Table A est un bug de
  l'un ou de l'autre, à réconcilier).
- Décidable : chaque job PASSE (le spécimen tourne avec son seul prérequis
  déclaré → résidu vérifié) ou ÉCHOUE (résidu non déclaré → constat). Sur
  `schedule`/`workflow_dispatch`, tout échec ouvre/alimente une issue
  `rot: <script> résidu-non-déclaré (hôte-nu)` via le `rot-issues.sh`
  existant (étendre son vocabulaire, pas le réécrire).
- Les résultats hôte-nu s'appendent à la série `data` avec une dimension
  distincte (p. ex. `os = clean-host:<mécanisme>` ou une colonne `lane`), de
  sorte que la durée-hôte-réaliste et la minimalité-hôte-nu ne se confondent
  pas dans les médianes du README.
- Branche `plan-11-preuve-hote-nu` poussée, PR ouverte vers master, PAS de
  merge, PAS d'attente CI au-delà d'un `workflow_dispatch` de test.

### 2. Périmètre fermé

Autorisés : `.github/workflows/clean-host.yml` (nouveau), extension de
`.github/scripts/rot-issues.sh` et `.github/scripts/append-runs.sh` (dimension
hôte-nu uniquement — ne pas toucher à leur logique existante), une petite
table de correspondance mécanisme → (conteneur, prérequis) si elle mérite un
fichier, `docs/journal.md` (append). **Interdits de périmètre** : les 15
scripts, `check.sh` (les oracles et le retry ne bougent pas), la matrice
`check.yml` existante, `generate-readme.sh`/`README.md` (l'intégration des
résultats hôte-nu au README est un plan ultérieur, une fois qu'on a des
données).

### 3. Moyens — et la carte des prérequis

Chaque job installe **un seul** prérequis, jamais l'image grasse du runner :

- **shebangs Nix (nix-shell, nix natif)** — prérequis : `nix` seul (installé
  dans un conteneur nu ; features `nix-command`+`flakes` activées pour le
  natif). Le reste (interpréteur, paquets, libs système) doit être provisionné
  par le shebang — c'est le résidu le plus faible, le test doit le confirmer.
- **uv** — prérequis : `uv` seul, **sans Python préinstallé**. Le job prouve
  (ou réfute) que uv télécharge un CPython managé. Résidu attendu : `uv` +
  réseau.
- **stack** — prérequis : `stack` seul, **sans GHC**. Prouve que stack
  provisionne GHC + le snapshot. Attention : le graphe à froid est lourd
  (cf. journal, TIMEOUT ubuntu à 1200 s) — prévoir un `TIMEOUT_S` adapté ou
  un cache de conteneur ; documenter, ne pas masquer.
- **cabal** — prérequis : `cabal` **ET** `ghc-9.10.3` (les DEUX sont
  déclarés). Le job hôte-nu de cabal *doit* installer GHC : c'est précisément
  le constat (cabal ne provisionne pas son compilateur — le plus grand résidu
  des trois Haskell). Le job documente ce résidu, il ne le contourne pas.
- **rust-script** — prérequis : `rustc` + `cargo` (toolchain déclarée
  présente). Résidu : toute la toolchain + linker.
- **deno** — prérequis : `deno` seul. Résidu : `deno` + registres.
- **babashka** — prérequis : `bb` seul. Résidu : `bb` (dont le jeu de libs
  compilées est gelé — un `add-deps` sur une lib non bundlée qui échouerait en
  hôte nu serait un constat intéressant).
- **scala-cli** — prérequis : `scala-cli` seul, **sans JVM préinstallée**.
  Prouve que scala-cli télécharge sa JVM via coursier. Résidu : `scala-cli` +
  Maven Central.

Interdits de moyens : préinstaller quoi que ce soit au-delà du prérequis
déclaré ; affaiblir un spécimen pour le faire passer ; masquer un TIMEOUT par
une tolérance plutôt que par un seuil justifié ; utiliser l'image runner
complète au lieu d'un conteneur minimal.

### 4. Journal

Entrée datée : la carte mécanisme → (conteneur, prérequis) retenue et sa
justification vs la Table A ; les résidus **falsifiés** (spécimens qui
utilisaient un résidu non déclaré — le cas échéant, c'est le produit
principal du plan) ; les pièges de conteneurisation (nix dans un conteneur,
seuils de timeout à froid sans cache, permissions).

### 5. Compte-rendu contraint

(a) la carte mécanisme → (conteneur, prérequis) ; (b) résultat par job du
`workflow_dispatch` de test (PASS = résidu vérifié / FAIL = résidu falsifié,
avec le détail) ; (c) diff résumé de `clean-host.yml` et des extensions de
`append-runs.sh`/`rot-issues.sh` ; (d) entrées journal ; (e) URL de la PR.
Puis fin de tour.

## Note de séquencement

Ce plan **change la topologie CI** (jobs isolés par mécanisme, conteneurs) :
il mérite sa propre validation, distincte du cycle 08–10. Une fois qu'il a
produit des données hôte-nu, un plan ultérieur pourra intégrer au README une
colonne « résidu vérifié en hôte nu » (transformant la Table A d'affirmée en
mesurée) — mais seulement une fois les données présentes.
