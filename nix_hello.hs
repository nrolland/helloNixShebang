#! /usr/bin/env nix-shell
#! nix-shell -i runghc -p 'let hs = haskellPackages.override { overrides = self: super: { type-level-sets = haskell.lib.dontCheck (haskell.lib.markUnbroken (haskell.lib.overrideSrc super.type-level-sets { src = fetchTarball "https://github.com/dorchard/type-level-sets/archive/e1ac77f297913087865bc06560e599d1fad04659.tar.gz"; version = "0.8.10.0"; })); }; }; in hs.ghcWithPackages (p: with p; [type-level-sets])'
#! nix-shell -I nixpkgs=https://github.com/NixOS/nixpkgs/archive/4382ed2b7a6839d4280a9b386db49cbc5907414d.tar.gz
-- type-level-sets-0.8.9.0 (Hackage) ne compile pas avec GHC >= 9.2 : erreur
-- "Uninferrable type variables" dans SetProperties (src/Data/Type/Set.hs).
-- Correctif upstream jamais publié sur Hackage ; on pointe sur le commit git
-- qui l'ajoute (e1ac77f, "Add kind signature in SetProperties", 2021-11-12),
-- la dernière révision avant le refactor "rearrangements" qui introduit de
-- nouvelles dépendances non nécessaires ici.

-- courtesy jyrimatti https://gist.github.com/jyrimatti/bd139e91ed257d37bc57c08ac505fc3f

{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE TypeApplications #-}

module Main where

import Data.Type.Set (Set(..), Proxy(..))

class Get a s where
  get :: Set s -> a

instance {-# OVERLAPS #-} Get a (a ': s) where
  get (Ext a _) = a

instance {-# OVERLAPPABLE #-} Get a s => Get a (b ': s) where
  get (Ext _ xs) = get xs

main :: IO ()
main = do
  let lst = Ext "hello" $ Ext 10 $ Empty
  putStrLn $ show $ get @String lst
