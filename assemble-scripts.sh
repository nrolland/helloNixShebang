#!/usr/bin/env bash
# Assemble each root script from its provisioning header and its program payload:
#   <script> = headers/<script>.header  +  payloads/<payload>
# The header carries everything mechanism-specific (shebang, inline manifests,
# pin directives, the pin-rationale comments, the blank separator); the payload
# is the program proper. Scripts sharing a payload (same program, different
# provisioning) point at the same file — that is the property the repository
# claims and now generates rather than duplicates by hand.
#
# Idempotent: a second run leaves the working tree unchanged (byte-identical
# output). The executable bit is (re)posed on every generated script.
#
# Portable bash 3.2 (the macOS CI runner executes this): no associative arrays,
# no bashisms past 3.2.
set -euo pipefail

cd "$(dirname "$0")"

assemble() {
  script="$1"
  payload="$2"
  header="headers/${script}.header"
  body="payloads/${payload}"
  if [ ! -f "$header" ]; then
    echo "assemble-scripts: missing header $header" >&2
    exit 1
  fi
  if [ ! -f "$body" ]; then
    echo "assemble-scripts: missing payload $body" >&2
    exit 1
  fi
  cat "$header" "$body" > "$script"
  chmod +x "$script"
  echo "assembled $script  (<= ${header} + ${body})"
}

# Table: <script>  <payload>.  Header is always headers/<script>.header.
# The three Haskell scripts share one program (type-level Get from a Set); the
# three Python and the two Ruby likewise. The rest are singletons kept for the
# uniformity of the assembler.
while read -r script payload; do
  [ -z "${script:-}" ] && continue
  case "$script" in \#*) continue ;; esac
  assemble "$script" "$payload"
done <<'TABLE'
nix_hello.hs                  typelevel-get-nix.hs
stack_hello_NotInStackage.hs  typelevel-get-stack.hs
cabal_hello.hs                typelevel-get-cabal.hs
stack_hello_InStackage.hs     http-get.hs
nix_hello.py                  prettytable.py
nixflake_hello.py             prettytable.py
uv_hello.py                   prettytable.py
nix_hello.rb                  hello.rb
nixflake_hello.rb             hello.rb
nix_hello.el                  hello.el
nix_hello.perl                hrefs.perl
deno_hello.ts                 is-odd.ts
bb_hello.clj                  squares.clj
rust_hello.rs                 parity.rs
scala_hello.scala             parity.scala
TABLE
