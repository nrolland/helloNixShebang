# Journal d'atelier

Mémoire des difficultés non triviales rencontrées et de leur résolution.
Append-only, une entrée datée par difficulté.

## 2026-07-23 — plan 08 (payload réifié : header ⊕ payload)

- **Table header/payload retenue.** Chaque script = `headers/<script>.header`
  ⊕ `payloads/<payload>`. Le header porte tout le provisioning (shebang,
  manifests inline, directives de pin, commentaires-rationale du pin, ligne
  vide de séparation) ; le payload est le programme. `assemble-scripts.sh`
  (bash 3.2 portable, table script→payload en heredoc + `while read`, pas de
  tableau associatif) régénère les 15 scripts, pose le bit exécutable, est
  idempotent. Payloads partagés :
    - `typelevel-get.hs` ← nix_hello.hs, stack_hello_NotInStackage.hs,
      cabal_hello.hs
    - `prettytable.py` ← nix_hello.py, nixflake_hello.py, uv_hello.py
    - `hello.rb` ← nix_hello.rb, nixflake_hello.rb
  Singletons : `http-get.hs`, `hello.el`, `hrefs.perl`, `is-odd.ts`,
  `squares.clj`, `parity.rs`, `parity.scala`.

- **Migration en deux temps, deux commits.** (1) Factorisation à l'identique
  prouvée par `git diff --exit-code` vide sur les 15 scripts avant toute
  harmonisation : les payloads Python (×3) et Ruby (×2) étaient DÉJÀ
  byte-identiques (partagés dès l'étape 1) ; les trois payloads Haskell
  divergeaient et ont d'abord été extraits per-script
  (`typelevel-get-{nix,stack,cabal}.hs`). (2) Harmonisation : fusion des trois
  en `typelevel-get.hs`, le diff des scripts à ce commit EST la liste des
  divergences résolues.

- **Divergences Haskell résolues à l'étape 2** (toutes sémantiquement neutres —
  commentaires, espacement, layout ; sortie « hello » inchangée) :
    - indentation de `get` : nix_hello.hs en décalage irrégulier (1 / 11 / 10
      espaces) → canonique 2 espaces (majoritaire, layout valide) ;
    - commentaire de provenance « courtesy jyrimatti … » : présent seulement
      dans la variante nix → conservé (crédite la source du procédé, appartient
      au programme) ; gagné par stack et cabal ;
    - footer emacs « -- Local Variables: … -- End: » : présent seulement dans
      cabal → retiré (directive d'éditeur, hors programme) ;
    - fin de fichier : ligne vide finale de la variante stack retirée →
      canonique un seul saut de ligne final.

- **Surprises de découpe.**
    - *Manifest à cheval (babashka).* Dans bb_hello.clj le bloc de
      provisioning est interleavé : `(require deps)` / `(add-deps …)` /
      `(require math)`, puis le programme. Découpe : les six premières lignes
      (shebang, blancs, le bloc requires+add-deps) → header ; le `(doseq …)`
      → payload.
    - *Deno sans séparateur.* deno_hello.ts n'a pas de ligne vide entre le
      shebang et le programme, et son `import npm:is-odd` est à la fois la
      déclaration de dépendance et du code : header = shebang seul, payload =
      l'import + la boucle (l'import est du programme, pas listé comme item de
      header dans le plan).
    - *Fins de fichier.* Les 15 scripts d'origine finissent tous par `\n` ;
      `head -n K` ⊕ `tail -n +K+1` préserve les octets exactement (y compris un
      éventuel `\n` final manquant), d'où la factorisation byte-exacte sans
      manipulation de fin de ligne.
    - *cabal_hello.hs — particularité machine (pas une régression).* Sur ce Mac,
      `cabal_hello.hs` FAIL en 0 s : `Cabal-5490 Cannot find the program 'ghc'`
      — cabal ne provisionne PAS son compilateur (contrairement à
      stack/nix-shell) et attend `ghc-9.10.3` sur le PATH, absent ici. master
      échoue à l'identique (vérifié) : indépendant de la factorisation. Documenté
      dans `known-failing.local` (gitignoré) → XFAIL local ; CI le fait tourner
      pour de vrai via haskell-actions/setup.

- **Garde de fraîcheur CI.** Ajoutée à `.github/workflows/check.yml` sur la
  jambe Linux, à côté de la garde README, même logique (artefact indépendant
  de l'OS, vérifié une seule fois) : `./assemble-scripts.sh` puis
  `git diff --exit-code` sur les 15 scripts. `generate-readme.sh` reste
  idempotent (il lit les scripts assemblés, byte-identiques après réassemblage
  — README inchangé, aucun ajustement du générateur nécessaire).

## 2026-07-18 — plan 07 (matrice macOS)

- **Extension de `.github/workflows/check.yml` à une matrice
  `{ubuntu-latest, macos-latest}`** avec `fail-fast: false` (les deux
  jambes vont au bout et produisent leur table de verdicts, même si l'une
  échoue) et `timeout-minutes: 120` (le défaut GitHub de 360 min
  laisserait un run macOS pathologique brûler des heures ; nix sans cache
  binaire complet et stack qui recompile sont lents à froid sur le runner
  ARM64).

- **Collision de nom d'artefact en matrice.** `actions/upload-artifact@v4`
  refuse deux artefacts de même nom ; le nom `logs` fixe aurait fait
  échouer l'upload de la seconde jambe. Corrigé en `logs-${{ matrix.os }}`.

- **Garde de fraîcheur README limitée à la jambe Linux
  (`if: runner.os == 'Linux'`).** Le README est un artefact unique
  indépendant de l'OS ; le vérifier deux fois est redondant et exposerait
  à une divergence awk BSD (macOS) / GNU (Linux) sans rapport avec la
  fraîcheur du fichier. Vérifié une seule fois là où le générateur tourne
  sous awk GNU.

- **Vérification pré-CI de la disponibilité des paquets nix sur
  aarch64-darwin.** `nix eval nixpkgs/4382ed2b#{babashka,rust-script,cargo,rustc}.drvPath`
  à la rev pinnée retourne un drvPath valide pour les quatre sur ce Mac
  ARM — pas de paquet absent pour le système du runner macOS, évite un
  aller-retour CI gaspillé sur un `nix profile add` qui échouerait à
  l'évaluation.

- **Premier run macOS : `check.sh` plantait immédiatement sur
  `KNOWN_FAILING[@]: unbound variable` (ligne 70), 0 verdict émis.** Cause :
  `/usr/bin/env bash` sur le runner macOS résout vers le bash 3.2 système,
  qui — sous `set -u` — lève « unbound variable » à l'expansion d'un
  tableau VIDE `"${KNOWN_FAILING[@]}"`. bash >= 4.4 (jambe Linux) la
  tolère, d'où une divergence pure macOS/Linux non révélée jusqu'ici.
  `KNOWN_FAILING` est vide par défaut (`known-failing.local` gitignoré,
  absent en CI), donc le bug se déclenchait au tout premier script.
  Corrigé par l'idiome portable `${arr[@]+"${arr[@]}"}` (expansion vide si
  tableau vide, éléments quotés préservés sinon) — harnais rendu robuste,
  aucun script de la matrice touché. Tous les steps de setup macOS (dont
  haskell-actions/setup GHC 9.10.3 sur ARM64, magic-nix-cache, les trois
  `nix profile add`) étaient déjà verts : seul le harnais bloquait.

- **Deuxième run macOS : les 15 scripts FAIL à 0s —
  `timeout: command not found` (check.sh ligne 123).** Cause : check.sh
  borne chaque script avec `timeout "${TIMEOUT_S}s"` (GNU coreutils) ;
  macOS/BSD ne fournit PAS `timeout` (il n'existe que sous le nom
  `gtimeout` via Homebrew coreutils, absent du runner). Le harnais
  échouait donc AVANT même de lancer chaque interpréteur (d'où les 0s
  uniformes). Divergence OS pure : sur Linux `timeout` vient de coreutils
  système. Corrigé en fournissant `timeout` par nix — step macOS-only
  `nix profile add nixpkgs/4382ed2b#coreutils` à la rev pinnée du dépôt
  (cohérent avec le pin par hash, symétrique avec Linux), la jambe Linux
  déjà verte laissée intacte. `mktemp` (bare) fonctionnait déjà sur le
  runner macOS — aucune erreur avant la ligne 123 —, donc pas d'autre
  incompatibilité coreutils à traiter. `~/.nix-profile/bin` est bien en
  PATH sur macOS (les `nix profile add` de setup avaient réussi), même
  mécanisme que Linux via nix-installer-action.

- **Troisième run macOS : vert sur les 15 scripts, aucun XFAIL requis.**
  Une fois les deux incompatibilités du HARNAIS levées (bash 3.2, `timeout`
  absent), tous les scripts de la matrice passent sur macos-latest (ARM64)
  comme sur Linux — la promesse « autosuffisant » tient sur les deux OS
  sans qu'aucun mécanisme soit structurellement incompatible avec le runner
  macOS. Divergence de TEMPS notable, seule vraie différence par-OS
  restante : les scripts `stack` compilent tout le graphe de lts-24.50 à
  froid sur macOS au premier run — `stack_hello_NotInStackage.hs` 356s et
  `stack_hello_InStackage.hs` 1028s (~17 min) — contre 1s chacun sur Linux
  où `~/.stack` était déjà chaud (restore-keys d'un run master antérieur).
  Ce premier run macOS peuple le cache `~/.stack` (clé indexée par
  `runner.os`), donc les runs macOS suivants (dont le cron hebdomadaire)
  seront rapides. Autres écarts mineurs de build à froid côté macOS :
  `nix_hello.hs` 100s (vs 41s), `nix_hello.el` 32s (vs 14s),
  `scala_hello.scala` 45s (vs 42s) — tous sous le budget. Job macOS total
  ~34 min, bien sous `timeout-minutes: 120`.

## 2026-07-18 — plan 06 (rust-script + scala-cli)

- **crates.io bloque les requêtes sans `User-Agent` identifiant.** Un
  `curl` nu vers `https://crates.io/api/v1/crates/<nom>` renvoie une
  erreur de policy ("We are unable to process your request..."), pas la
  fiche du crate. Résolu en passant un `User-Agent` avec un contact
  (`-A "helloNixShebang-plan06 (contact: ...)"`), conformément à la
  politique d'accès de crates.io.

- **Le nom de crate deviné par analogie avec `npm:is-odd` n'existe pas.**
  `is_odd` (soulignés, comme le nom de fonction Rust idiomatique) n'est
  pas un nom de crate publié ; crates.io suggère `is-odd` (trait d'union),
  qui existe bien (v1.1.1) mais est un crate parodique répliquant le
  drame npm original — pas un choix sérieux pour démontrer une résolution
  de dépendance. Remplacé par `num-integer` (crate numérique établi,
  `Integer::is_odd`), épinglé en `=0.1.46`.

- **`search.maven.org` sans le paramètre `core=gav` masque les versions
  réelles.** La recherche par défaut sur `g:com.lihaoyi AND a:upickle_3`
  renvoie `latestVersion: 4.1.0-test-publish`, une version de test, pas la
  dernière version stable publiée. Passer `core=gav` avec `rows=20` liste
  toutes les versions `(g,a,v)` réellement indexées ; `4.1.0` en est la
  plus haute version stable, retenue pour le pin `//> using dep
  com.lihaoyi::upickle:4.1.0`.

- **`scala-cli shebang` laisse `.bsp/` et `.scala-build/` dans le
  répertoire courant après exécution** (cache de build local, sortie
  BSP pour IDE) — répertoires non trackés, non commités (hors du
  périmètre fermé du plan 06, qui n'autorise pas de modification de
  `.gitignore`). Nettoyés manuellement après chaque test local
  (`rm -rf .bsp .scala-build`) ; signalé dans la description de la PR
  comme amélioration opportuniste possible (ajouter ces deux entrées à
  `.gitignore`, par analogie avec `dist-newstyle` pour cabal), non
  exécutée ici pour respecter le périmètre.
