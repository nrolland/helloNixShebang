# Plan 02 — Harnais de vérification et CI

## Contexte

La thèse du dépôt (« ces scripts sont autosuffisants ») n'est vérifiée par
rien. Ce plan la rend vérifiable : un harnais local `check.sh`, puis GitHub
Actions qui l'exécute sur push et en cron hebdomadaire. C'est le plan pivot —
tous les suivants s'appuient dessus.

## Préconditions

Plan 01 mergé (arbre propre).

## Conception du harnais

Deux classes de scripts, à traiter différemment :

| Script | Sortie | Oracle |
|--------|--------|--------|
| `nix_hello.hs` | déterministe (`"hello"`) | diff contre `expected/nix_hello.hs.out` |
| `nix_hello.py` | déterministe (table N/N²) | diff contre fichier attendu |
| `nix_hello.rb` | déterministe | diff |
| `nix_hello.el` | déterministe (`Hi` sur stderr) | diff (capturer stderr) |
| `stack_hello_NotInStackage.hs` | déterministe (`"hello"`) | diff |
| `cabal_hello.hs` | déterministe (`"hello"`) | diff |
| `nix_hello.perl` | réseau (hrefs de nixos.org) | exit 0 **et** stdout non vide |
| `stack_hello_InStackage.hs` | réseau (httpbin.org) | exit 0 **et** stdout contient `The status code was: 200` |

Exigences du harnais (non négociables) :

- **Résultats en flux** : une ligne par script *au moment où il finit*
  (`PASS/FAIL/TIMEOUT nom durée`), jamais un rapport uniquement final.
- **Timeout par script** : 600 s (premier run télécharge des toolchains) ;
  un script pathologique devient un échec nommé, pas une nuit silencieuse.
- **Filtre** : `./check.sh nix_hello.py` n'exécute que ce script.
- Logs complets par script dans `logs/<script>.log` (gitignoré), la
  conversation/CI ne montre que les verdicts.
- Code de sortie global : 0 ssi tous PASS.

## Tâches

1. Branche `plan-02-harnais` depuis `master`.
2. Créer `expected/` : exécuter chaque script déterministe une fois,
   inspecter la sortie à la main (elle doit correspondre à ce que le code
   fait), l'enregistrer comme fichier attendu. Ne jamais enregistrer une
   sortie sans l'avoir lue.
3. Écrire `check.sh` (bash, `set -euo pipefail`) selon la conception
   ci-dessus. La liste des scripts et leur classe d'oracle sont **dans une
   table au début du fichier**, pas éparpillées.
4. Ajouter `logs/` au `.gitignore`.
5. État attendu des scripts au moment de ce plan : `cabal_hello.hs` pinne
   `ghc-8.0.1` (2016) et échouera très probablement ; d'autres peuvent avoir
   pourri. **Un échec de script n'est pas un échec du plan.** Le harnais doit
   le nommer, pas le masquer : introduire une liste `KNOWN_FAILING` dans
   `check.sh` (verdict `XFAIL`, n'affecte pas le code de sortie), y placer
   les scripts cassés constatés, et lister ces constats dans la PR. Le plan
   03 videra cette liste.
6. Workflow `.github/workflows/check.yml` :
   - déclencheurs : `push`, `pull_request`, `schedule` (cron hebdomadaire,
     p.ex. lundi 06:00 UTC), `workflow_dispatch` ;
   - runner `ubuntu-latest` ;
   - installer Nix (`DeterminateSystems/nix-installer-action`) + cache
     (`DeterminateSystems/magic-nix-cache-action`) ;
   - installer stack et cabal pour les trois scripts non-nix
     (`haskell-actions/setup`) ;
   - exécuter `./check.sh` ;
   - en cas d'échec, uploader `logs/` comme artefact.
   Un seul job séquentiel suffit (8 scripts) ; ne pas sur-architecturer en
   matrice tant que la durée totale reste < 30 min.
7. Badge du workflow en tête de `README.md` (seule modification du README
   autorisée dans ce plan).
8. Pousser, vérifier que le workflow passe **réellement** sur GitHub
   (`gh run watch`), corriger jusqu'au vert. PR, merge.

## Hors périmètre

- Réparer les scripts cassés (plan 03) — les nommer XFAIL suffit.
- Générer le README (plan 05).
- Matrice macOS (optionnelle, plus tard).

## Critère de réussite

`./check.sh` passe localement avec verdicts en flux ; le workflow est vert
sur GitHub ; chaque script a un verdict nommé (PASS ou XFAIL documenté).
