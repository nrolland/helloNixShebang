[![check](https://github.com/nrolland/helloNixShebang/actions/workflows/check.yml/badge.svg)](https://github.com/nrolland/helloNixShebang/actions/workflows/check.yml)

# Self-sufficient scripts

One executable file that carries its own runtime. The interpreter and the
dependencies are declared **inside** the script — no separate install, no
environment to set up first. The same tiny program is shown through nine
mechanisms (Nix, uv, deno, stack, cabal, babashka, rust-script, scala-cli) so
you can compare them directly.

## What one looks like

Take `uv_hello.py`. The **header** is the runtime contract; the **payload** is
the ordinary program.

```python
#!/usr/bin/env -S uv run --script   # header: uv is the interpreter (PEP 723)
# /// script                        # header: inline dependency manifest
# requires-python = ">=3.12"        # header: interpreter constraint
# dependencies = ["prettytable==3.16.0"]   # header: dependency, exact version
# ///
                                    # (blank line: header / payload separator)
import prettytable                  # payload: the program

t = prettytable.PrettyTable(["N", "N^2"])
for n in range(1, 10):
    t.add_row([n, n * n])
print(t)
```

Swap the header, keep the payload, and you get another row of the table below.
`./assemble-scripts.sh` builds every script as
`headers/<script>.header ⊕ payloads/<payload>`, byte-identical — so the payload
is a constant and every difference between specimens is due to the *mechanism*.

## Which one to use

- **Strongest reproducibility, and you control the host** → a Nix shebang. It
  pins the *entire* closure — interpreter, packages, system libraries — by hash.
  Needs `nix` on the host; the first run may pull from the cache.
- **One portable file, modern tooling, minimal footprint** → `uv` (Python),
  `deno` (TypeScript) or `scala-cli` (Scala). A single binary is the only real
  prerequisite; it provisions the interpreter/JVM and resolves exactly-pinned
  dependencies.
- **The toolchain is already installed, you just want to pin deps** → `cabal`
  or `rust-script`. Cheapest to adopt, largest residue: the compiler must
  already be there, and its version floats.

## The specimens

<!-- BEGIN GENERATED MATRIX -->
| Script | Language | Mechanism | Pins | CI median s (Ubuntu / macOS) |
|---|---|---|---|---|
| `nix_hello.hs` | Haskell | nix-shell shebang | nixpkgs@4382ed2b7a68 | 39 / 48 |
| `nix_hello.py` | Python | nix-shell shebang | nixpkgs@4382ed2b7a68 | 3 / 7 |
| `nix_hello.rb` | Ruby | nix-shell shebang | nixpkgs@4382ed2b7a68 | 2 / 4 |
| `nix_hello.el` | Emacs Lisp | nix-shell shebang | nixpkgs@4382ed2b7a68 | 12 / 15 |
| `nix_hello.perl` | Perl | nix-shell shebang | nixpkgs@4382ed2b7a68 | 2 / 4 |
| `nixflake_hello.rb` | Ruby | native nix shebang (flake) | nixpkgs@4382ed2b7a68 | 1 / 1 |
| `nixflake_hello.py` | Python | native nix shebang (flake) | nixpkgs@4382ed2b7a68 | 1 / 1 |
| `stack_hello_NotInStackage.hs` | Haskell | stack script | resolver lts-24.50 | 99 / 2 |
| `stack_hello_InStackage.hs` | Haskell | stack script | resolver lts-24.50 | 1091 / 2 |
| `cabal_hello.hs` | Haskell | cabal script | index-state 2026-07-17T00:00:00Z, ghc-9.10.3 | 5 / 12 |
| `uv_hello.py` | Python | uv (PEP 723) | PEP 723: prettytable==3.16.0 | 0 / 1 |
| `deno_hello.ts` | TypeScript | deno | import npm:is-odd@3.0.1 | 1 / 0 |
| `bb_hello.clj` | Clojure | babashka | deps.edn runtime: org.clojure/math.numeric-tower @0.1.0 | 2 / 8 |
| `rust_hello.rs` | Rust | rust-script | Cargo.toml: num-integer@0.1.46 | 3 / 7 |
| `scala_hello.scala` | Scala | scala-cli | using dep: com.lihaoyi::upickle:4.1.0 | 36 / 49 |
<!-- END GENERATED MATRIX -->

*Latencies are the median wall-clock time measured in CI (`schedule` / `push` /
`workflow_dispatch` runs), from the append-only
[`data`](https://github.com/nrolland/helloNixShebang/blob/data/data/runs.tsv)
branch. They are durations in CI, not cold/warm figures — a cache-cold first
run can be far slower (the same `stack_hello_InStackage.hs` measured 2 s on one
leg and ~18 min on the other). The series is young, so `n = 1` per cell today.*

## What each mechanism still assumes

"Self-sufficient" is a spectrum. The column that matters is the **residue** —
what is *not* pinned, and so is still assumed to be on the host.

<!-- BEGIN GENERATED RESIDUE -->
| Mechanism | Host prerequisite | Pinned | Not pinned (residue) |
|---|---|---|---|
| `nix-shell` shebang | `nix` (store + daemon) | full closure by nixpkgs hash: interpreter, packages, system libs | the `nix` binary; store/daemon; network to the substituter on first run |
| native `nix` shebang (flake) | `nix` ≥ 2.19, `nix-command` + `flakes` enabled | same: full closure by nixpkgs hash | `nix` ≥ 2.19 with those features; store/daemon; network on first run |
| `stack` script | `stack`; C toolchain/linker | GHC + Stackage snapshot (exact versions) via `--resolver lts-24.50` | the `stack` binary; host C toolchain/linker; Hackage/Stackage reachable |
| `cabal` script | `cabal`; `ghc-9.10.3` on PATH; C toolchain/linker | `index-state` + named compiler (`with-compiler: ghc-9.10.3`) | `cabal` **and** a GHC of the exact name — cabal does not provision it (largest residue of the three Haskell); populated Hackage index |
| `uv` (PEP 723) | `uv` | exact packages (`prettytable==3.16.0`) | the `uv` binary; exact Python version floats in `requires-python >=3.12` (uv fetches a managed Python if absent); PyPI reachable |
| `deno` | `deno` | direct imports at exact version (`npm:is-odd@3.0.1`) | the `deno` binary and version; npm/jsr reachable on first run |
| `babashka` | `bb` | Maven deps at exact version (`math.numeric-tower 0.1.0`) | the `bb` binary — its built-in library set is frozen by version (cheshire is bundled); Maven Central reachable for the added dep |
| `rust-script` | `rust-script`; `rustc`/`cargo`; linker | crates at exact version (`num-integer =0.1.46`) | the whole Rust toolchain (`rustc`/`cargo`, floating); host linker; crates.io reachable |
| `scala-cli` | `scala-cli` | Scala version (`//> using scala 3.8.3`) + deps (`upickle:4.1.0`) | the `scala-cli` binary — it fetches its JVM via coursier if absent (JVM version not pinned); Maven Central reachable |
<!-- END GENERATED RESIDUE -->

Roughly four families, though several straddle two: full-environment (the Nix
shebangs), provisioned-toolchain (`stack`, `uv`, `scala-cli` fetch their own
compiler/interpreter/JVM), runtime-with-inline-deps (`deno`, `babashka`), and
wrapper-over-present-toolchain (`cabal`, `rust-script`). `uv` provisions the
interpreter *and* inlines its deps; `babashka` carries a frozen library set in
its binary — the overlaps are the point.

## How this stays honest

The repository is also a small longevity instrument. A weekly CI cron re-runs
every specimen on a fresh Linux and macOS host and checks that each contract
still resolves and runs — not merely that it once did. Decay events (a channel
reaching EOL, an https redirect, an unfixed compiler bug, a cold-build timeout)
are logged in [`docs/journal.md`](docs/journal.md).

It does **not** claim to be zero-dependency (the launcher must exist),
hermetic (CI pre-installs the toolchains, so a script could quietly use an
undeclared residue and still pass), or offline (several mechanisms reach a
registry on the first run).

Background on the Nix shebangs that seeded the collection:
[chriswarbo.net](http://chriswarbo.net/projects/nixos/nix_shell_shebangs.html)
and the ["Use as an interpreter"](https://nix.dev/manual/nix/stable/command-ref/nix-shell.html#use-as-a--interpreter)
section of the Nix manual.

## Contributing

**Please PR if you want to share more of these.**
