#!/usr/bin/env nix
#! nix shell --impure --expr ``
#! nix with (import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/4382ed2b7a6839d4280a9b386db49cbc5907414d.tar.gz") {});
#! nix python3.withPackages (ps: with ps; [ prettytable ])
#! nix ``
#! nix --command python3

import prettytable

# Print a simple table.
t = prettytable.PrettyTable(["N", "N^2"])
for n in range(1, 10):
    t.add_row([n, n * n])

print(t)
