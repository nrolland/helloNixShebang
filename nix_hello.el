#! /usr/bin/env nix-shell
#! nix-shell -i "emacs --script"  -p "pkgs.emacs.pkgs.withPackages(epkgs: (with epkgs.melpaPackages; [ dash ]))"
#! nix-shell -I nixpkgs=https://github.com/NixOS/nixpkgs/archive/4382ed2b7a6839d4280a9b386db49cbc5907414d.tar.gz

(package-initialize)
(require 'dash)

(message "Hi")
