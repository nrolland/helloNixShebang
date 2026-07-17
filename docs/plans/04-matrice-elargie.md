# Plan 04 — Matrice élargie (mécanismes hors Nix)

## Contexte

Depuis 2022, l'écosystème a convergé vers le design que ce dépôt documentait
en avance : *métadonnées de dépendances inline dans le fichier exécutable*.
Ce plan ajoute les représentants majeurs, chacun avec pinning explicite —
la colonne « méthode de pinning » est ce qui rend la matrice intéressante.

## Préconditions

Plan 03 mergé (harnais en place, colonne nix complète).

## Périmètre : trois mécanismes, un script chacun

| Fichier | Mécanisme | Pinning |
|---------|-----------|---------|
| `uv_hello.py` | `uv run` + PEP 723 | `# /// script` avec `dependencies` versionnées + `requires-python` |
| `deno_hello.ts` | deno | imports `npm:`/`jsr:` à version exacte |
| `bb_hello.clj` | babashka | `deps` en en-tête `babashka/…` versionné |

Règles :

- **Même famille de payloads que l'existant** : `uv_hello.py` reprend le
  payload prettytable de `nix_hello.py` (même sortie attendue — réutiliser le
  fichier `expected/` existant si la sortie est identique, sinon fichier
  propre). Les deux autres : un payload déterministe court utilisant au moins
  une dépendance externe (sinon le mécanisme de résolution n'est pas
  exercé).
- Shebangs de la forme `#!/usr/bin/env -S uv run --script` etc. — vérifier
  la syntaxe exacte de chaque outil dans sa doc, puis par exécution réelle.
- Chaque outil requis (uv, deno, bb) : vérifier sa présence locale, sinon
  l'obtenir via `nix shell nixpkgs#<outil>` pour le test local.

## Tâches

1. Branche `plan-04-matrice` depuis `master`.
2. Écrire les trois scripts, les exécuter localement, produire leurs
   `expected/`.
3. Les ajouter à la table de `check.sh` (classe déterministe).
4. CI : installer uv (`astral-sh/setup-uv`), deno (`denoland/setup-deno`),
   babashka (`turtlequeue/setup-babashka` ou via nix) dans le workflow.
   Versions des actions épinglées.
5. `./check.sh` complet local, push, CI verte, PR, merge.

## Extension optionnelle (seulement si les trois passent sans friction)

`rust-script` et `scala-cli`, mêmes règles. Ne pas l'entamer si le plan a
déjà demandé plus d'un aller-retour de débogage CI — livrer trois mécanismes
vérifiés vaut mieux que cinq douteux.

## Hors périmètre

- README (plan 05).
- Tout mécanisme nécessitant un service externe authentifié.

## Critère de réussite

Trois nouveaux scripts PASS localement et en CI ; chacun exerce réellement
une résolution de dépendance externe pinnée.
