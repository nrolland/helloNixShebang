#! /usr/bin/env nix-shell
#! nix-shell -i python -p "python3.withPackages (ps: with ps; [ prettytable ])"
#! nix-shell -I nixpkgs=channel:nixos-21.11

import prettytable

# Print a simple table.
t = prettytable.PrettyTable(["N", "N^2"])
for n in range(1, 10):
    t.add_row([n, n * n])

print(t)
