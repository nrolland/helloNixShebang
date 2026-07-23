#!/usr/bin/env stack
-- stack --resolver lts-24.50 script --extra-dep https://github.com/dorchard/type-level-sets/archive/e1ac77f297913087865bc06560e599d1fad04659.tar.gz --package type-level-sets

-- (the package type-level-sets is not in stackage)
--
-- type-level-sets-0.8.9.0 (Hackage) ne compile pas avec GHC >= 9.2 (voir
-- nix_hello.hs) ; --extra-dep pointe sur le commit git qui corrige le
-- problème, jamais publié sur Hackage.

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
