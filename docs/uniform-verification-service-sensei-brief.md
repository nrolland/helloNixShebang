# Request for Advice: Is a Receipt Layer for Content-Addressed Verification Worth Building?

*Revision 2. The first version of this brief asked whether a uniform,
language-neutral verification protocol with public infrastructure deserved to
exist. Review identified a conflation at its core and a substrate question it
had left open. This revision re-derives the proposal from the corrected
argument rather than patching the original text.*

## What the review established (taken as premises here)

1. **The original brief conflated two products.**
   (a) A *receipt system*: the claim "this source checks" reified as data —
   content-addressed, replayable, citable — where execution is performed by
   whoever has an interest in it (the author's CI, the recipient's machine, an
   independent verifier).
   (b) A *public execution service*: a zero-install playground with
   artifact-pinned environments.
   They share machinery but not economics. Every sustainability objection in
   the original brief (denial of service, enormous closures, deliberate
   nontermination, the cost of a free service) attaches only to (b). This
   revision proposes (a); (b) is an optional extension someone else can fund.

2. **The substrate is Nix, not a new protocol.** The correspondence is
   term-for-term: environment digest = pinned flake reference resolving to a
   store closure; constrained invocation = derivation (sandboxed, network
   disabled, declared inputs — already Nix's semantics); action identity =
   derivation hash; shared cache = binary cache; remote execution = remote
   builders. The operationally-uniform envelope the original brief sketched
   already exists as the Bazel Remote Execution API; its adoption pattern
   shows that demand for such a layer lives *inside* build systems, not among
   artifact recipients. What is missing is a thin product, not a protocol.

3. **The artifact names; the receipt resolves.** Opaque digests embedded in
   source comments are illegible to humans and die with their resolution
   service. The artifact should carry a human-readable pinned name — the Nix
   shebang form `#!nix shell nixpkgs#agda ...` is exactly this — and the
   *receipt* records the immutable resolution (store paths, derivation hash).

4. **The unit of identity is the source tree** (NAR or git-tree digest), with
   the standalone file as the singleton tree. This absorbs the
   "files are not the right unit" objection without a layered-manifest design.

5. **The semantic claim is pinned, not assumed.** The uniform layer certifies
   only: *this process, in this closure, terminated with this status and these
   outputs*. What a green result *means* ("no postulates, under `--safe`, no
   `sorry`") belongs to a language adapter — which is therefore part of the
   invocation and itself content-addressed. The interpretation is pinned with
   the same rigor as the compiler.

6. **Interactive development is out of scope.** Warm sessions keyed by
   environment digest are a different product (Agdapad occupies it). Receipts
   apply to checkpoints and final artifacts.

## The question, sharpened

Given a thin layer over Nix that turns a verification action into a
derivation and its outcome into a content-addressed receipt:

> Would portable, replayable verification receipts change how proofs and
> generated code are exchanged — or would recipients trust the green badge
> without ever replaying, reducing the content-addressing to ceremony?

I am asking for an assessment of adoption and trust dynamics, not of
technical feasibility; feasibility is not in doubt, since every component
exists.

## Motivation in one example (re-read through the receipt lens)

A standalone Cubical Agda module beginning

```agda
{-# OPTIONS --cubical --lossy-unification #-}
```

failed under Agda 2.8.0 with Cubical 0.9 because an imported module used the
infective `--guardedness` option; adding `--guardedness` made it check. A
plain green/red indicator blurs three distinct facts:

1. the original source did not check in the specified environment;
2. the failure was a source/environment compatibility diagnostic, not an
   infrastructure failure;
3. one particular change produced an accepted module under one particular
   immutable toolchain.

A receipt is precisely the datum that keeps these three facts separate: it
ties a source-tree digest, a resolved environment, a pinned adapter's
structured report, and a terminal status into one immutable, replayable
record.

## The proposed product

A service and a client sharing one action identity:

- **Remote:** `POST (source tree, pinned flake reference)` → the service
  builds a sandboxed *check derivation* → returns a receipt as JSON at a
  content-addressed URL:

  ```text
  Receipt
    source-tree digest
    resolved environment (store paths, derivation hash)
    adapter identity (content-addressed)
    terminal status
    structured adapter report
    resource measurements
  ```

- **Local:** `nix build` of the *same* derivation. Because the action
  identity is the derivation hash, local cache, binary caches and the remote
  service share results by construction. Local-first behavior is inherited
  from the substrate, not built.

- **Adapter (Agda, the only one in v1):** emits, as a derivation *output*
  rather than a log, the structured report: unsolved metas, postulates,
  effective options, termination/positivity/coverage status, imported
  modules, established declarations.

The trust claim of a receipt is exactly: *executor E attests that action A
produced result R*. What makes it citable is not the attestation but the
replayability — the receipt is a pointer to an experiment the reader can
rerun. Signatures, transparency logs and multi-verifier quorums are the Nix
trusted-substituter problem, already solved conceptually, and excluded from
v1.

## Who is expected to feel the pain

Two groups only, stated honestly:

- **Proof-assistant users exchanging standalone files** (Zulip, mailing
  lists, papers, bug reports). Real but small, and currently muddling
  through with playgrounds.
- **Automated systems** — agents producing Agda/Lean proofs or generated
  code need a decidable, sandboxed check-with-receipt endpoint to ground
  their own claims. This is the strongest and fastest-growing demand, and
  the group most tolerant of a non-interactive, tree-in/receipt-out
  interface.

Reviewers, educators, archivists and maintainers are secondary
beneficiaries, not primary demand.

## Deliberately excluded

- A new manifest or metadata format (derivations and flake references
  suffice).
- A neutral, language-independent registry or resolution namespace.
- Signatures, transparency logs, multi-verifier quorums.
- Interactive sessions and editor integration.
- Any language beyond Agda; any platform beyond `linux/amd64`.
- An embedded-metadata standard: the action is the pair
  (tree, flake reference), accepted explicitly; embedding the reference in
  the file (shebang, comment) is presentation, written by tooling, not a
  protocol surface.
- Free public execution at scale (product (b) above).

## Risks that survive the revision

- **A digest is an identifier, not preservation.** Long-term availability of
  closures and receipts is an institutional problem (retention, mirrors, a
  public-interest archive), not an engineering one. The product can only be
  honest about what it retains.
- **Provenance maintained by hand decays.** If authors must manually embed
  or transport references, they will not. The reference must be written by
  the editor or CI — which moves the adoption problem into tooling.
- **Names and curation.** People reason in "Agda 2.8.0 with Cubical 0.9",
  not hashes. A curated registry of a few dozen pinned environments may
  matter more than any mechanism.
- **Nix coupling.** The local path requires Nix. The `curl` path does not,
  but then "replayable" means "replayable by someone with Nix" — is that
  enough for the citation use-case?

## The minimal experiment

- One platform (`linux/amd64`), one assistant (Agda), ~10 curated pinned
  environments, one operation (type-check a bounded tree, network disabled).
- The HTTP endpoint and the local `nix build` path sharing one derivation
  identity.
- Structured Agda report; immutable receipt URL.

Measured falsifiers, stated in advance:

1. **Replay rate.** Do recipients ever rerun the action, or do they trust
   the badge? If nobody replays, a playground permalink captures all
   realized value and the proposal fails.
2. **Embed rate.** Do references get attached to artifacts at all once
   tooling writes them — and preserved when the artifact is copied into a
   paper, an issue, a chat message?
3. **Reuse.** Are environments and results actually shared across users and
   files, or is every action unique?
4. **Agent demand.** Do automated clients use the receipt, or would a plain
   sandboxed checker API without content-addressing have served them
   equally well?

## Advice requested

The feasibility questions from revision 1 are settled by construction. The
open questions are about adoption, trust and institutions:

1. **Replay.** Under what conditions does a recipient replay a receipt
   rather than trust it? Is there any precedent (reproducible-builds
   rebuilders, artifact-evaluation committees) suggesting a realistic
   replay rate above zero?

2. **Tooling-borne provenance.** If references must be written by editors
   and CI to survive, is the product actually an *integration* (an Agda
   mode, a CI action, an agent tool) with the service as backend — and
   should it be built and marketed as such?

3. **The agent use-case.** For automated verification of generated proofs
   and code, is content-addressing load-bearing (caching, auditability,
   deduplication across agents) or incidental — would a stateless sandboxed
   checker API capture that demand without the receipt machinery?

4. **The institution.** Who plausibly operates the memo table — a
   proof-assistant community organization, a foundation like Software
   Heritage, a university library — and what retention promise is both
   honest and useful?

5. **Nix coupling.** Is requiring Nix for local replay a fatal adoption
   constraint for the target groups, or acceptable given that the primary
   clients (CI, agents, the hosted endpoint) do not expose it?

6. **The adapter as semantic claim.** What must the pinned Agda report
   contain for a receipt to be worth citing in review or scholarship — and
   is there a principled boundary between "operational fact" and
   "semantic interpretation" that the adapter should never cross?

The central question is no longer whether a universal layer is possible,
but whether receipts — replayable, content-addressed verification claims —
change how proofs and generated code are exchanged, or merely decorate the
existing trust-the-badge workflow at the cost of a new service to run.
