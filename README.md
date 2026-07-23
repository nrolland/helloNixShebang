[![check](https://github.com/nrolland/helloNixShebang/actions/workflows/check.yml/badge.svg)](https://github.com/nrolland/helloNixShebang/actions/workflows/check.yml)

# Self-sufficient scripts — a longevity instrument

**The runtime contract travels with the script.** An executable script normally
depends on an invisible environment — an interpreter, libraries, a toolchain —
assumed present on the host. This repository makes that environment explicit
*inside* each script: every specimen declares how to obtain its interpreter and
its dependencies. It is not "runtime-free" (a machine with no runtime runs
nothing); it is *runtime-declaring*. The weekly CI cron is the measurement — it
checks, on a fresh Linux and macOS host, whether each mechanism still honours
its contract, i.e. still resolves its pinned dependencies and runs, not merely
that it once did. The events of decay (a channel reaching EOL, an https
redirect, an unfixed kind bug, an unstable httpbin, bash 3.2 on the macOS
runner) are the primary product, logged in [`docs/journal.md`](docs/journal.md).

**Same program, variable header — a control.** Each specimen re-expresses one
shared payload under a different self-sufficient header.
`./assemble-scripts.sh` regenerates every script as
`headers/<script>.header ⊕ payloads/<payload>`, byte-identical. The shared
payload is the **experimental control**: because the program is held constant,
every difference between specimens — latency, host residue, failure mode — is
attributable to the *mechanism*, not to the program.

Background on the Nix shebangs that seeded the collection:

- http://chriswarbo.net/projects/nixos/nix_shell_shebangs.html
- the ["Use as a interpreter"](https://nix.dev/manual/nix/stable/command-ref/nix-shell.html#use-as-a--interpreter)
  section of the Nix manual

## Anatomy of one script

Take `uv_hello.py`. The **header** carries the runtime contract; the **payload**
(`payloads/prettytable.py`, shared with `nix_hello.py` and `nixflake_hello.py`)
is the program.

```python
#!/usr/bin/env -S uv run --script   # header — uv is the interpreter (PEP 723 script mode)
# /// script                        # header — inline dependency manifest (PEP 723)
# requires-python = ">=3.12"        # header — interpreter constraint: a lower bound (floats)
# dependencies = [                  # header — dependencies…
#     "prettytable==3.16.0",        # header — …pinned to an exact version
# ]                                 # header —
# ///                               # header — end of manifest
                                    # (blank line — the header ⊕ payload separator)
import prettytable                  # payload — the program (identical across the 3 Python specimens)

# Print a simple table.
t = prettytable.PrettyTable(["N", "N^2"])
for n in range(1, 10):
    t.add_row([n, n * n])

print(t)
```

The header is the entire contract with the host; the payload is what the
contract exists to run. Swap the header, keep the payload, and you have another
row of Table B.

## Table A — mechanisms and host residue

For each of the nine mechanisms: what the host must still provide, what the
header pins, and — the column that matters — **what it does not pin** (the
residue the host is assumed to supply). This residue matrix is the single
source of truth of the comparison; read it as the answer to "what is still
assumed if I run this on a bare host?". Each cell has been verified against the
tool's documentation, the behaviour observed in CI, and `docs/journal.md`.

<!-- BEGIN GENERATED RESIDUE -->
| Mécanisme | Prérequis hôte | Épinglé | Résidu non épinglé |
|---|---|---|---|
| `nix-shell` shebang | `nix` (store + daemon) | clôture complète par hash nixpkgs : interpréteur, paquets, libs système | binaire `nix` et sa version ; store/daemon ; réseau vers le substituter au premier run |
| `nix` shebang natif (flake) | `nix` ≥ 2.19, features `nix-command` + `flakes` activées | idem : clôture complète par hash nixpkgs | binaire `nix` ≥ 2.19 avec `nix-command`/`flakes` ; store/daemon ; réseau au premier run |
| `stack` script | `stack` ; toolchain C/linker | GHC + snapshot Stackage (versions exactes) via `--resolver lts-24.50` | binaire `stack` ; toolchain C/linker de l'hôte (incident Xcode CLT, plan 01) ; Hackage/Stackage et le tarball extra-dep joignables |
| `cabal` script | `cabal` ; `ghc-9.10.3` sur le PATH ; toolchain C/linker | `index-state` + compilateur nommé (`with-compiler: ghc-9.10.3`) | binaire `cabal` ET un GHC du nom exact déjà présent — cabal ne le provisionne pas (échec local PATH, journal) ; index Hackage peuplé ; toolchain C/linker. Le plus grand résidu des trois Haskell |
| `uv` (PEP 723) | `uv` | paquets exacts (`prettytable==3.16.0`) | binaire `uv` ; la version exacte de Python flotte dans `requires-python >=3.12` (uv télécharge un Python managé si absent) ; PyPI joignable |
| `deno` | `deno` | imports directs à version exacte (`npm:is-odd@3.0.1`) | binaire `deno` et sa version ; registres (npm/jsr) joignables au premier run |
| `babashka` | `bb` | deps Maven à version exacte (`math.numeric-tower 0.1.0`) | binaire `bb`, dont le jeu de bibliothèques compilées en dur dépend de la version (cheshire bundlé, plan 04) ; Maven Central joignable pour la dep ajoutée |
| `rust-script` | `rust-script` ; `rustc`/`cargo` ; linker | crates à version exacte (`num-integer =0.1.46`) | toute la toolchain Rust (`rustc`/`cargo`, versions flottantes) ; linker de l'hôte ; crates.io joignable |
| `scala-cli` | `scala-cli` | version Scala (`//> using scala 3.8.3`) + deps (`upickle:4.1.0`) | binaire `scala-cli` — il télécharge sa JVM via coursier si absente (version de JVM non épinglée dans le script) ; Maven Central joignable |
<!-- END GENERATED RESIDUE -->

By *provisioning grouping* — a reading aid, not a partition, since several
mechanisms straddle two cells: (i) **full environment** — the Nix shebangs pin
interpreter, packages and system libraries by hash; (ii) **provisioned
toolchain** — `stack`, `uv` and `scala-cli` download their compiler / interpreter
/ JVM themselves; (iii) **runtime with inline deps** — `deno` and `babashka`
assume the runtime binary and resolve declared deps at run time; (iv) **wrapper
over a present toolchain** — `cabal` and `rust-script` require the compiler to
pre-exist. The overlaps are the point: `uv` provisions the interpreter *and*
inlines its deps (ii ∩ iii); `babashka` carries a *frozen* library set compiled
into its binary, so its own version is an implicit pin (cf. cheshire, journal
plan 04). The taxonomy introduces; the residue matrix decides.

## Table B — specimens and measured CI latency

The 15 specimens, augmented with the **median wall-clock duration measured in
CI**, per OS, from the longitudinal series in
[`data/runs.tsv`](https://github.com/nrolland/helloNixShebang/blob/data/data/runs.tsv)
(orphan `data` branch). Each cell carries its sample size `n=`.

<!-- BEGIN GENERATED MATRIX -->
| Script | Langage | Mécanisme | Pin | Oracle | Ubuntu médiane (s) | macOS médiane (s) |
|---|---|---|---|---|---|---|
| `nix_hello.hs` | Haskell | nix-shell shebang | nixpkgs@4382ed2b7a68 | fichier (`expected/nix_hello.hs.out`) | 39 (n=1) | 48 (n=1) |
| `nix_hello.py` | Python | nix-shell shebang | nixpkgs@4382ed2b7a68 | fichier (`expected/nix_hello.py.out`) | 3 (n=1) | 7 (n=1) |
| `nix_hello.rb` | Ruby | nix-shell shebang | nixpkgs@4382ed2b7a68 | fichier (`expected/nix_hello.rb.out`) | 2 (n=1) | 4 (n=1) |
| `nix_hello.el` | Emacs Lisp | nix-shell shebang | nixpkgs@4382ed2b7a68 | réseau (stderr contient « Hi ») | 12 (n=1) | 15 (n=1) |
| `nix_hello.perl` | Perl | nix-shell shebang | nixpkgs@4382ed2b7a68 | réseau (stdout non vide) | 2 (n=1) | 4 (n=1) |
| `nixflake_hello.rb` | Ruby | nix shebang natif (flake) | nixpkgs@4382ed2b7a68 | fichier (`expected/nixflake_hello.rb.out`) | 1 (n=1) | 1 (n=1) |
| `nixflake_hello.py` | Python | nix shebang natif (flake) | nixpkgs@4382ed2b7a68 | fichier (`expected/nixflake_hello.py.out`) | 1 (n=1) | 1 (n=1) |
| `stack_hello_NotInStackage.hs` | Haskell | stack script | resolver lts-24.50 | fichier (`expected/stack_hello_NotInStackage.hs.out`) | 99 (n=1) | 2 (n=1) |
| `stack_hello_InStackage.hs` | Haskell | stack script | resolver lts-24.50 | réseau (stdout contient « The status code was: 200 ») | 1091 (n=1) | 2 (n=1) |
| `cabal_hello.hs` | Haskell | cabal script | index-state 2026-07-17T00:00:00Z, ghc-9.10.3 | fichier (`expected/cabal_hello.hs.out`) | 5 (n=1) | 12 (n=1) |
| `uv_hello.py` | Python | uv (PEP 723) | PEP 723: prettytable==3.16.0 | fichier (`expected/nix_hello.py.out`) | 0 (n=1) | 1 (n=1) |
| `deno_hello.ts` | TypeScript | deno | import npm:is-odd@3.0.1 | fichier (`expected/deno_hello.ts.out`) | 1 (n=1) | 0 (n=1) |
| `bb_hello.clj` | Clojure | babashka | deps.edn runtime: org.clojure/math.numeric-tower @0.1.0 | fichier (`expected/bb_hello.clj.out`) | 2 (n=1) | 8 (n=1) |
| `rust_hello.rs` | Rust | rust-script | Cargo.toml: num-integer@0.1.46 | fichier (`expected/rust_hello.rs.out`) | 3 (n=1) | 7 (n=1) |
| `scala_hello.scala` | Scala | scala-cli | using dep: com.lihaoyi::upickle:4.1.0 | fichier (`expected/scala_hello.scala.out`) | 36 (n=1) | 49 (n=1) |
<!-- END GENERATED MATRIX -->

**Latency legend.** Durations are the median `duration_s` per script × OS over
complete-run events (schedule, push, workflow_dispatch — all on hosted
runners). These are *durations in CI*, not cold/warm figures: the cache state
of the runner is not recorded in the data, so no cell is labelled "cold" or
"warm". The first run on a host with no cache can be dramatically slower — the
same `stack_hello_InStackage.hs` measured 2 s on one leg and 1091 s (~18 min)
on the other in this very snapshot, and the journal records a cold `stack` at
1028 s on macOS (plan 07). Small-`n` cells are the current reality of a young
series, not a stability claim.

Table B is generated by `generate-readme.sh` from the scripts, the oracle table
in `check.sh`, and a frozen latency snapshot of the `data` branch; Table A is
generated from a verified facts table in the same script. Both are regenerated
on every push and CI fails if either drifts from its sources (see
`.github/workflows/check.yml`). Do not edit between the markers by hand.

## Which mechanism to choose

- **You control the host and want the strongest reproducibility guarantee** — a
  Nix shebang: it pins the *entire* closure (interpreter, packages, system
  libraries) by hash. Cost: the host must have `nix`, and the first run may pull
  from the substituter.
- **You want one portable file with a modern tool and minimal host residue** —
  `uv` (Python), `deno` (TypeScript) or `scala-cli` (Scala): a single binary is
  the only real prerequisite; it provisions the interpreter / JVM and resolves
  exactly-pinned dependencies.
- **The toolchain is already installed and you only need to pin dependencies** —
  `cabal` or `rust-script`: cheapest to adopt, largest residue (the compiler
  must pre-exist and its version floats).

## Limits

This repository does not claim:

- **zero-dependency** — the bootstrap prerequisite remains: every mechanism
  assumes at least its own launcher (`nix`, `uv`, `bb`, `stack`, …) on the host.
  See the "host prerequisite" and "residue" columns of Table A.
- **hermetic** — CI pre-installs the toolchains (Determinate nix-installer,
  `haskell-actions/setup`, `nix profile add`); a script could quietly use an
  undeclared host residue and still pass. The *bare-host proof* that would
  measure this boundary — running each specimen on a host provisioned with
  nothing but the launcher — is future work (a plan 11), out of scope here.
- **offline** — several mechanisms reach a registry or substituter on the first
  run (see the residue column): nixpkgs cache, PyPI, npm / jsr, Maven Central,
  Hackage / Stackage, crates.io.

## Contributing

**Please PR if you want to share more of those.**
