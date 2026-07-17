# Plan 05 — README généré depuis les fichiers

## Contexte

Le README doit présenter la matrice mécanisme × langage × pinning × statut.
Une table maintenue à la main divergera des fichiers ; elle doit donc être
**générée** — code as documentation, jamais écrire à la main ce qu'un
programme peut produire.

## Préconditions

Plan 04 mergé (la matrice est complète, la génération porte sur son état
final).

## Conception

- `generate-readme.sh` (bash + awk, zéro dépendance exotique) qui, pour
  chaque script exécutable du dépôt :
  - lit les premières lignes et en extrait : mécanisme (nix-shell / nix
    shebang / stack / cabal / uv / deno / babashka — déduit du shebang),
    langage (extension), méthode de pinning (la ligne de pin elle-même,
    tronquée : rev nixpkgs abrégée, résolveur LTS, contrainte PEP 723…) ;
  - vérifie l'existence d'un oracle (`expected/<script>.out` ou entrée
    réseau dans `check.sh`).
- Le README garde une partie rédigée à la main (intro, liens, invitation à
  PR) et une section générée entre marqueurs :
  ```
  <!-- BEGIN GENERATED MATRIX -->
  <!-- END GENERATED MATRIX -->
  ```
  Le script remplace uniquement l'intérieur des marqueurs.
- La partie rédigée est réécrite une fois dans ce plan : conserver l'esprit
  de l'actuelle (référence à chriswarbo.net et au manuel Nix — vérifier que
  les deux URLs répondent encore, remplacer l'ancre du manuel par l'URL
  actuelle de la section shebang), une phrase sur la thèse du dépôt (« même
  payload, header variable ; le CI hebdomadaire est la preuve »), badge du
  workflow déjà en place.

## Tâches

1. Branche `plan-05-readme` depuis `master`.
2. Écrire `generate-readme.sh`, l'exécuter, relire le README produit
   intégralement (la sortie d'un générateur se lit avant de se commiter).
3. Garde de fraîcheur en CI : étape du workflow qui exécute
   `./generate-readme.sh && git diff --exit-code README.md` — un README
   désynchronisé casse le build.
4. Push, CI verte, PR, merge.
5. **Clôture du cycle** : déplacer les cinq plans de `docs/plans/` vers
   `docs/plans/old/` (convention du dépôt parent : plan validé ⇒ archivé),
   dans la même PR ou une PR de ménage immédiate.

## Hors périmètre

- Tout changement de comportement des scripts.
- Site web, GitHub Pages, etc.

## Critère de réussite

`./generate-readme.sh` est idempotent (deuxième exécution : diff vide) ; la
table du README reflète exactement les fichiers présents ; la garde de
fraîcheur est active en CI ; les plans exécutés sont archivés.
