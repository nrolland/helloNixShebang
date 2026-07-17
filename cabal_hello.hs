#! /usr/bin/env cabal
{- cabal:
index-state: 2026-07-17T00:00:00Z
with-compiler: ghc-9.10.3
build-depends: base, type-level-sets
source-repository-package
  type: git
  location: https://github.com/dorchard/type-level-sets
  tag: e1ac77f297913087865bc06560e599d1fad04659
-}

-- Mode script cabal : voir "cabal run" / "Scripts" dans le cabal user guide
-- https://cabal.readthedocs.io/en/stable/cabal-commands.html#cabal-run
--
-- type-level-sets-0.8.9.0 (Hackage) ne compile pas avec GHC >= 9.2 (voir
-- nix_hello.hs) ; source-repository-package pointe sur le commit git qui
-- corrige le problème, jamais publié sur Hackage.

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

-- Local Variables:
--  haskell-compile-command: "./Main.hs"
-- End:
