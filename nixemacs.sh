#! /usr/bin/env nix-shell
#! nix-shell -i "emacs --script"  -p "pkgs.emacsWithPackages(epkgs: (with epkgs.melpaPackages; [ dash ]))"
#! nix-shell -I nixpkgs=channel:nixos-18.03
(package-initialize)
(require 'dash)

(message "Hi")
