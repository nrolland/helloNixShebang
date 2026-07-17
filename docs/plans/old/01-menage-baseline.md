# Plan 01 — Ménage et baseline

## Contexte

L'arbre de travail contient un diff non commité, résidu d'un test manuel :

- `nix_hello.hs` : suppression du pragma `{-# LANGUAGE PolyKinds #-}`
- `stack_hello_InStackage.hs` : suppression d'un bloc de commentaire obsolète
  (variante de résolveur lts-14.20)

Par ailleurs : `old/stackNostackageKO.hs` est un fichier mort, `.DS_Store`
traîne (non tracké), pas de `.gitignore`.

## Tâches

1. Branche `plan-01-menage` depuis `master`.
2. **Vérifier le diff en attente avant de le commiter** : exécuter les deux
   scripts modifiés.
   ```sh
   ./nix_hello.hs > /tmp/logs-plan01-nix.txt 2>&1        # attendu : "hello"
   ./stack_hello_InStackage.hs > /tmp/logs-plan01-stack.txt 2>&1  # attendu : status 200 + corps JSON
   ```
   Timeout 600 s chacun (premier run = téléchargement GHC/paquets).
   - Si `nix_hello.hs` échoue à cause du pragma retiré : restaurer le pragma,
     re-tester, et le noter dans le message de commit.
   - Si l'échec est autre (canal 21.11 indisponible, réseau) : commiter quand
     même le diff en le signalant `[unverified]` dans le message — la
     vérification continue arrive au plan 02 ; ne pas entamer la migration de
     pin ici (c'est le plan 03).
3. Commit 1 : le diff en attente, message factuel (« remove stale pragma and
   comment block, residue of manual channel test »).
4. Commit 2 : `git rm old/stackNostackageKO.hs` (le répertoire `old/` disparaît
   avec son seul fichier).
5. Commit 3 : `.gitignore` minimal :
   ```
   .DS_Store
   result
   dist-newstyle
   ```
6. PR vers `master`, merge (méthode merge), ne pas supprimer la branche.

## Hors périmètre

- Toute modification de pin, de résolveur ou de README.
- Tout nouveau fichier de script.

## Critère de réussite

`git status` propre sur `master` après merge ; `old/` absent ; les deux
scripts modifiés ont été exécutés (ou l'échec est documenté dans le commit).
