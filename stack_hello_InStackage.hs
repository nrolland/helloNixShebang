#!/usr/bin/env stack
-- stack --resolver lts-14.20 script

-- or
{- stack
  script
  --resolver lts-14.20
  --package turtle
  --package "stm async"
  --package http-client,http-conduit
-}

-- this script makes use of the http-client library, which is in stackage


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
