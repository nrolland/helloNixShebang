#!/usr/bin/env bb

(require '[babashka.deps :as deps])
(deps/add-deps '{:deps {org.clojure/math.numeric-tower {:mvn/version "0.1.0"}}})
(require '[clojure.math.numeric-tower :as math])

(doseq [n (range 1 10)]
  (println (str n "\t" (math/expt n 2))))
