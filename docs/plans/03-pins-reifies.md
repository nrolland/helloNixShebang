# Plan 03 — Pins réifiés et modernisation

## Contexte

Le pin actuel `-I nixpkgs=channel:nixos-21.11` est un pointeur mutable vers
un canal EOL : l'identité du snapshot est conflée avec la disponibilité d'un
service (le cache de nixos.org). La réification correcte est un contenu
adressé : tarball GitHub à révision fixe. Même mouvement côté Haskell :
résolveur stack et pin cabal datent de 2016–2021.

Ce plan vide aussi la liste `KNOWN_FAILING` du harnais (plan 02).

## Préconditions

Plan 02 mergé. `nix --version` ≥ 2.19 localement (shebang `nix` natif).

## Tâches

1. Branche `plan-03-pins` depuis `master`.
2. **Résoudre les versions courantes au moment de l'exécution** (ne pas
   copier de valeurs depuis ce plan, elles seraient périmées) :
   - révision nixpkgs : `git ls-remote https://github.com/NixOS/nixpkgs
     refs/heads/nixos-<dernier-stable>` — le nom du dernier canal stable se
     lit sur https://status.nixos.org ;
   - dernier LTS Stackage : https://www.stackage.org/lts ;
   - GHC récent supporté par ce LTS.
3. Scripts `nix-shell` (`nix_hello.{hs,py,rb,perl,el}`) : remplacer la ligne
   ```
   #! nix-shell -I nixpkgs=channel:nixos-21.11
   ```
   par
   ```
   #! nix-shell -I nixpkgs=https://github.com/NixOS/nixpkgs/archive/<rev>.tar.gz
   ```
   avec `<rev>` la révision résolue à l'étape 2. Une seule révision pour tous
   les scripts. Vérifier chaque script via `./check.sh <script>` après
   modification ; ajuster ce que le bump de nixpkgs casse (noms de paquets,
   pragmas devenus superflus…) en gardant le payload identique au caractère
   près entre les trois variantes Haskell (c'est la propriété du dépôt :
   même payload, header variable).
4. **Nouvelle colonne : shebang `nix` natif** (Nix ≥ 2.19). Deux fichiers
   représentatifs, pas un par langage :
   - `nixflake_hello.rb` — cas simple :
     ```
     #!/usr/bin/env nix
     #! nix shell github:NixOS/nixpkgs/<rev>#ruby --command ruby
     ```
   - `nixflake_hello.py` — cas `withPackages` (prettytable), même payload que
     `nix_hello.py`. La syntaxe exacte pour une expression dans un shebang
     `nix shell` est à vérifier dans le manuel Nix (section « nix shebang »,
     quoting spécifique) ; si l'expression inline s'avère impraticable,
     documenter la limite dans un commentaire du fichier et se rabattre sur
     un attribut plat — la limite constatée est une donnée de la matrice,
     pas un échec.
   Les deux nouveaux scripts entrent dans `check.sh` (classe déterministe).
5. `stack_hello_InStackage.hs` et `stack_hello_NotInStackage.hs` : bump du
   résolveur vers le LTS courant. Attention au second : il dépend de
   `type-level-sets` **hors Stackage** — vérifier que le paquet compile
   encore avec le GHC du nouveau LTS ; sinon rester sur le LTS le plus récent
   qui fonctionne et le noter en commentaire dans le fichier.
6. `cabal_hello.hs` : `with-compiler` vers un GHC installé par CI,
   `index-state` récent, retirer le commentaire « Can't find information on
   how to use cabal script mode » (le mode script est documenté depuis) et le
   remplacer par un renvoi vers la doc cabal. Sortir le script de
   `KNOWN_FAILING` si (et seulement si) `./check.sh cabal_hello.hs` passe.
7. `KNOWN_FAILING` doit être vide à la fin du plan. Si un script résiste,
   c'est un point d'arrêt : documenter précisément l'échec dans la PR et le
   laisser XFAIL explicitement justifié — jamais silencieux.
8. `./check.sh` complet en local, puis push, CI verte (`gh run watch`),
   PR, merge.

## Hors périmètre

- Mécanismes hors Nix/Haskell (plan 04).
- README au-delà d'aucune modification (plan 05).

## Critère de réussite

Plus aucune occurrence de `channel:` dans les shebangs (`grep -r "channel:"
*.hs *.py *.rb *.perl *.el` vide) ; deux scripts shebang `nix` natif présents
et PASS ; `KNOWN_FAILING` vide ou chaque entrée justifiée dans le fichier ;
CI verte.
