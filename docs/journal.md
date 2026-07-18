# Journal d'atelier

Mémoire des difficultés non triviales rencontrées et de leur résolution.
Append-only, une entrée datée par difficulté.

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
