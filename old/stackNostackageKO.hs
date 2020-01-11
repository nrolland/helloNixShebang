#!/usr/bin/env stack
-- stack --resolver lts-14.20 script --package type-level-sets


-- this used to fail as a script with
--     Local packages are not allowed when using the script command. Packages found:
--     type-level-sets-0.8.7.0
-- but could be launched as
-- stack --resolver lts-9.21 runghc --package http-conduit --package type-level-sets -- stacknostackage.hs

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

