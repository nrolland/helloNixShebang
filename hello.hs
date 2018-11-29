#! /usr/bin/env nix-shell
#! nix-shell -i runghc -p "haskellPackages.ghcWithPackages(p: with p; [type-level-sets])"
#! nix-shell -I nixpkgs=channel:nixos-18.03

-- courtesy jyrimatti https://gist.github.com/jyrimatti/bd139e91ed257d37bc57c08ac505fc3f

{-# LANGUAGE PolyKinds #-}
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
