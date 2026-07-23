# Journal d'atelier

Mémoire des difficultés non triviales rencontrées et de leur résolution.
Append-only, une entrée datée par difficulté.

## 2026-07-23 — premier événement de pourriture capté par l'instrument

- **`stack_hello_InStackage.hs` TIMEOUT sur ubuntu (run 30029415240, push
  master).** Le graphe Stackage lts-24.50 à froid sur ubuntu-latest a dépassé
  `TIMEOUT_S=1200` et a été tué (verdict `TIMEOUT`, `duration_s=1200`,
  consigné dans `data/runs.tsv`). Le même spécimen a été mesuré à **1091 s**
  sur le `workflow_dispatch` juste précédent (2b0e185) : le build à froid est
  **pile à la frontière du timeout** (1091 s < 1200 s < build suivant). Ce
  n'est pas une régression du dépôt mais une **propriété mesurée du mécanisme
  stack** (coût du graphe à froid, variance de cache CI). L'instrument a fait
  son travail : il a capté l'événement, l'a horodaté, l'a rangé dans la série.
  Question de réglage laissée à l'owner (hors périmètre du cycle 08–10 clos) :
  relever `TIMEOUT_S` pour stack, améliorer le taux de hit du cache
  `~/.stack`, ou accepter la variance comme donnée. Le job `record`
  (`if: always()`) a bien enregistré la ligne malgré l'échec de la jambe —
  comportement voulu : c'est là que le record est le plus utile.

- **Sérialisation des écritures concurrentes sur `data` — vérifiée en réel.**
  Deux merges master rapprochés (#14, #15) ont lancé deux runs `push`
  concurrents ; leurs deux jobs `record` ont écrit `data/runs.tsv` sans
  corruption ni doublon (90 lignes = 3 runs distincts × 15 scripts × 2 OS ;
  `(sha,event)` distincts par run). Le `git pull --rebase` + re-push ×3 du
  plan 09 a absorbé la course comme prévu.

## 2026-07-23 — plan 10 (README de l'instrument : anatomie, résidu, latences)

- **Source de vérité de chaque table, et pourquoi deux blocs générés.**
  `generate-readme.sh` produit désormais DEUX sections encadrées. Table B
  (spécimens) reste dérivée des scripts + de la table SCRIPTS de `check.sh`,
  augmentée de deux colonnes de latence. Table A (matrice de résidus) est
  générée depuis un heredoc `RESIDUE_ROWS` DANS le script : une seule source
  de vérité, réécrite entre les marqueurs `BEGIN/END GENERATED RESIDUE`. Le
  bloc de remplacement a été généralisé en fonction `replace_between BEGIN END
  CONTENU FICHIER`, appelée deux fois ; elle relit le fichier à chaque appel,
  donc le décalage de lignes du premier remplacement n'affecte pas le second.

- **Latences : instantané FIGÉ, pas lecture live de la branche `data`.** La
  garde de fraîcheur CI est `./generate-readme.sh && git diff --exit-code
  README.md`. Si le générateur lisait `data/runs.tsv` en direct (via
  `git show origin/data:…`), le README dériverait à chaque nouvelle ligne
  poussée sur `data` et la garde casserait. Les médianes sont donc calculées
  hors-ligne et collées dans un heredoc `LAT_FACTS` (script⇥os⇥médiane⇥n),
  rendant le générateur déterministe. `data/runs.tsv` ne vit que sur la
  branche orpheline `data`, absent de `master` — un instantané figé est de
  toute façon la seule option compatible avec la garde. Régénération = recalcul
  des médianes + recollage du heredoc.

- **État des données au moment de la génération.** Branche `data` re-fetchée :
  30 lignes, UN seul run (`run_id` 30021341170, événement `workflow_dispatch`),
  15 scripts × 2 OS. Donc **n=1 pour chaque cellule** — affiché tel quel avec
  son `n=`, sans qualificatif de stabilité (plan). Les deux runs `push`
  annoncés en vol n'avaient pas encore appendé leurs lignes à l'heure de la
  génération. Médiane d'un singleton = la valeur. Événements retenus :
  schedule + push + workflow_dispatch (tous runners hébergés) ; `pull_request`
  exclu à la source par le job `record`, donc absent du TSV.

- **La variance de cache est DANS l'instantané, pas étiquetée.**
  `stack_hello_InStackage.hs` mesure 1091 s sur ubuntu (build à froid, cache
  `~/.stack` absent sur ce `workflow_dispatch`) contre 2 s sur macOS (cache
  chaud d'un run antérieur) — même script, écart ×545 imputable au seul état
  du cache, qui n'est pas dans les données. D'où : pas d'étiquette froid/chaud,
  « durée en CI », et une légende qui renvoie au constat du journal (stack à
  froid 1028 s sur macOS, plan 07).

- **Cellules de l'ébauche (plan §3) corrigées après vérification.**
    - *nix shebang natif* — l'ébauche donnait comme résidu « nix ≥ 2.19 »
      seulement. Vérifié (doc Nix, wiki NixOS) : le shebang interpreter natif
      exige la NOUVELLE CLI et les flakes — features expérimentales
      `nix-command` + `flakes` activées (nixflake_hello.py utilise `--expr`,
      nixflake_hello.rb la forme `github:…`). Résidu corrigé pour l'inclure.
    - *uv fournit-il Python ?* (point à trancher du plan) — OUI, confirmé
      (docs.astral.sh/uv) : `uv run` télécharge un Python managé si aucun ne
      satisfait `requires-python`. `requires-python = ">=3.12"` est une borne
      INFÉRIEURE : la version exacte flotte. Résidu conservé, incertitude levée.
    - *scala-cli gère-t-il sa JVM ?* (point à trancher) — OUI, confirmé
      (scala-cli under-the-hood, coursier) : scala-cli télécharge et déballe
      une JVM via coursier si aucune n'est présente. La version de JVM n'étant
      pas épinglée dans le script (`//> using scala` ne pin que Scala), elle
      flotte. Résidu affirmé, incertitude levée.
    - *cabal* — ébauche : « cabal binary ET un GHC du bon nom ». Précisé en
      ajoutant deux résidus grounded (header + journal plan 08) : l'index
      Hackage doit être peuplé (`cabal update`) avant que le solveur connaisse
      `type-level-sets`, et la toolchain C/linker de l'hôte est requise pour
      lier (cabal ne provisionne ni GHC ni le linker). Reste le plus grand
      résidu des trois Haskell.
    - *stack* — ajout mineur : le tarball `--extra-dep` (NotInStackage) doit
      être joignable, au même titre que Hackage/Stackage (grounded : header).
    - *babashka* (point à trancher « libs gelées ») — confirmé par le journal
      (plan 04, cheshire bundlé) : le jeu de bibliothèques compilées en dur
      dépend de la version du binaire `bb` ; son numéro de version est donc un
      pin implicite. Cellule conservée.
  Les autres cellules (nix-shell, deno, rust-script) correspondaient à
  l'ébauche et sont publiées telles quelles.

- **Anatomie : spécimen choisi.** `uv_hello.py` — contrat entièrement
  contenu dans le fichier (manifeste PEP 723 inline, pin `==` visible) et
  payload `prettytable.py` PARTAGÉ avec `nix_hello.py` et `nixflake_hello.py`,
  ce qui matérialise le point du « contrôle expérimental » (même programme,
  header variable).

## 2026-07-23 — plan 09 (instrumentation : série temporelle + auto-issues)

- **Schéma de `data/runs.tsv` et sa justification.** Colonnes (TAB) :
  `utc_date  sha  event  os  script  verdict  duration_s  run_id`. Une ligne
  par script × OS et par run. `utc_date` en ISO 8601 UTC
  (`date -u +%Y-%m-%dT%H:%M:%SZ`) — jamais d'heure locale dans les données,
  sinon la série n'est plus comparable entre runners. `sha` + `run_id`
  rendent chaque ligne remontable à son commit et à son run GitHub (lien
  reconstructible). `event` (schedule/push/workflow_dispatch) distingue
  l'échantillonnage régulier du cron des mesures ponctuelles. `os` +
  `script` + `verdict` + `duration_s` sont la mesure elle-même. La table
  vit sur une branche ORPHELINE `data` (créée au premier append si absente,
  en-tête posé alors) : append-only, découplée de l'historique du code, elle
  ne pollue pas `master` et se lit indépendamment. Le harnais `check.sh`
  ne fait qu'ÉMETTRE `logs/verdicts.tsv` (`script  verdict  duration_s`) ;
  il ne transporte ni n'interprète — isolation mesure / transport / signalement.

- **Orchestration du job `record`.** Un SEUL job, `needs: check`,
  `if: always() && (schedule || workflow_dispatch || push-sur-master)` : il
  s'exécute après les deux jambes de la matrice, même si l'une a échoué
  (c'est le cas où enregistrer et signaler compte le plus), mais jamais sur
  les runs de PR (bruit). Faire de `record` l'unique écrivain de `data`
  supprime la course entre OS par construction : au lieu de deux jobs (un
  par OS) qui pousseraient concurremment sur `data`, un job downstream lit
  les verdicts des deux jambes via artefacts et écrit une fois. La seule
  course résiduelle est inter-runs (deux `record` concurrents) — absorbée
  par re-fetch + re-append + re-push, 3 tentatives, chaque tentative
  repartant d'un clone frais (donc jamais de double-append).

- **Pièges rencontrés.**
    - *Transport des verdicts entre jobs = artefacts.* Deux jobs de matrice
      sur des runners éphémères distincts ne partagent pas de système de
      fichiers ; le seul canal job→job est l'artefact. L'upload des logs,
      auparavant `if: failure()`, est passé à `if: always()` — la série
      enregistre CHAQUE run, pas seulement les échecs, et l'extrait de log
      d'une future issue `rot` doit exister même quand tout passe. Un seul
      artefact `logs-<os>` par jambe porte `verdicts.tsv` + les `<script>.log`.
      Téléchargement via `pattern: logs-*` (sous-dossiers séparés) : robuste
      à une jambe manquante, l'`os` se lit du nom de dossier (`logs-<os>`).
    - *Permissions.* `GITHUB_TOKEN` par défaut est en lecture seule sur les
      workflows durcis ; pousser `data` et ouvrir des issues exige des
      permissions explicites AU NIVEAU DU JOB `record` (`contents: write`,
      `issues: write`) — accordées là et nulle part ailleurs (moindre
      privilège). Push de la branche via un remote `x-access-token:$GH_TOKEN`.
    - *Dédoublonnage des issues `rot`.* Par SCRIPT (pas par os+verdict) : un
      même spécimen qui pourrit sur les deux OS ne doit générer qu'une issue.
      `gh issue list --label rot --state open` filtré sur les titres
      commençant par `rot: <script> ` ; si présent → commentaire, sinon →
      création. La logique vit dans `.github/scripts/rot-issues.sh`, testable
      hors CI avec `DRY_RUN=1` (écho des commandes `gh`, aucune vraie issue) ;
      testée localement sur un `verdicts.tsv` fabriqué (un PASS ignoré, un
      FAIL, un TIMEOUT) → un `issue create` par spécimen cassé, extrait de log
      inclus (repli `(log indisponible)` si le `.log` manque sur une jambe).

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
