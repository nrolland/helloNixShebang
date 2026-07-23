# Plan 08 — Le payload réifié (header ⊕ payload)

## Contexte

La propriété fondatrice du dépôt — « même payload, header variable » — est
affirmée mais nulle part vérifiée : les trois variantes Haskell partagent
leur payload par copier-coller, les trois Python de même. Ce plan isole les
deux constituants (le header de provisioning, le payload) en fichiers de
première classe et fait des scripts leur composition **générée**, avec garde
de fraîcheur en CI — même statut que le README. Ajouter un mécanisme devient
« écrire un header », immédiatement comparable à tous les autres sur payload
identique.

## Contrat

### 1. Objectif décidable

- `payloads/` et `headers/` existent ; chaque script de la racine est la
  concaténation `headers/<script>.header` + `payloads/<payload>.<ext>`,
  produite par `./assemble-scripts.sh` (exécutable, bit x posé sur les
  sorties).
- Idempotence : deuxième exécution ⇒ `git diff --exit-code` vide sur les 15
  scripts.
- Garde de fraîcheur en CI (jambe Linux, à côté de celle du README) :
  `./assemble-scripts.sh && git diff --exit-code *.hs *.py *.rb *.perl *.el *.ts *.clj *.rs *.scala`.
- `./check.sh` complet PASS localement (hors particularités machine
  documentées dans known-failing.local) ; `./generate-readme.sh` toujours
  idempotent (il lit les scripts assemblés — inchangé ou ajusté a minima).
- Branche `plan-08-payload` poussée, PR ouverte vers master, PAS de merge,
  PAS d'attente de la CI (le superviseur la surveille).

### 2. Périmètre fermé

Autorisés : `payloads/*` (nouveaux), `headers/*` (nouveaux),
`assemble-scripts.sh` (nouveau), les 15 scripts de la racine (uniquement via
l'assembleur — voir migration ci-dessous), `.github/workflows/check.yml`
(la garde de fraîcheur uniquement), `generate-readme.sh` (uniquement si la
lecture des en-têtes doit s'ajuster), `README.md` (uniquement via
`./generate-readme.sh`), `docs/journal.md` (append). Rien d'autre —
ni check.sh (les noms de scripts ne changent pas), ni expected/.

### 3. Moyens, et la migration

**Découpe.** Le header d'un script = tout ce qui relève du mécanisme de
provisioning : lignes shebang, manifests inline (`{- cabal: -}` et
`{- project: -}`, bloc `//! ```cargo`, bloc PEP 723 `# /// script`,
directives `//> using`, `(babashka.deps/add-deps …)` si en tête), y compris
la ligne vide de séparation. Le payload = le programme, pragmas LANGUAGE
compris (partagés entre variantes Haskell). Tout pin vit dans un header.

**Table de partage attendue** (à vérifier contre les fichiers réels) :
- `payloads/typelevel-get.hs` ← nix_hello.hs, stack_hello_NotInStackage.hs, cabal_hello.hs
- `payloads/prettytable.py` ← nix_hello.py, nixflake_hello.py, uv_hello.py
- un payload Ruby partagé ← nix_hello.rb, nixflake_hello.rb (vérifier
  l'identité effective des deux corps actuels)
- singletons (1 header + 1 payload chacun, pour l'uniformité de
  l'assembleur) : nix_hello.el, nix_hello.perl, stack_hello_InStackage.hs,
  deno_hello.ts, bb_hello.clj, rust_hello.rs, scala_hello.scala.

**Migration en deux temps, dans cet ordre :**
1. Factoriser à l'identique : découper les fichiers actuels en
   headers/payloads tels quels, assembler, exiger
   `git diff --exit-code` sur les 15 scripts — la factorisation est prouvée
   exacte avant toute harmonisation.
2. Harmoniser les payloads censés partagés s'ils divergent (commentaires,
   espacement — p.ex. le commentaire de provenance jyrimatti présent dans la
   seule variante nix) : choisir une forme canonique, la justifier dans le
   message de commit, ré-assembler. Le diff des scripts à ce commit EST la
   liste des divergences résolues. `./check.sh` re-PASS après (les
   commentaires ne changent pas la sortie ; si un expected/ bouge, c'est le
   signe d'une harmonisation qui dépasse les commentaires — s'arrêter et le
   signaler).

Interdits : modifier la sémantique d'un script, toucher aux oracles, éditer
un script de la racine à la main après la factorisation, merge.
`assemble-scripts.sh` en bash portable (pas de bashisme > 3.2 : la CI macOS
l'exécutera — cf. l'idiome tableaux vides de check.sh).

### 4. Journal

Entrée datée : la table header/payload retenue, les divergences résolues à
l'étape 2, toute surprise de découpe (manifest à cheval, bit exécutable,
fins de fichier).

### 5. Compte-rendu contraint

(a) arborescence payloads/ + headers/ (noms retenus) ; (b) preuve de la
factorisation exacte (étape 1) et liste des harmonisations (étape 2) ;
(c) sortie de `./check.sh` ; (d) entrées journal ; (e) URL de la PR. Puis
fin de tour.
