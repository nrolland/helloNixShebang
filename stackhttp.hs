#!/usr/bin/env stack
-- stack --resolver lts-12.5 script

-- or
{- stack
  script
  --resolver lts-6.5
  --package turtle
  --package "stm async"
  --package http-client,http-conduit
-}
{-# LANGUAGE OverloadedStrings #-}
import qualified Data.ByteString.Lazy.Char8 as L8
import           Network.HTTP.Simple

-- An equivalent pure haskell file can also be run as
-- stack runghc --package http-conduit -- http.hs

main :: IO ()
main = do
    response <- httpLBS "http://httpbin.org/get"

    putStrLn $ "The status code was: " ++
               show (getResponseStatusCode response)
    print $ getResponseHeader "Content-Type" response
    L8.putStrLn $ getResponseBody response
