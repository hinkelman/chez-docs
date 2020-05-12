#!/usr/bin/env scheme-script
;; -*- mode: scheme; coding: utf-8 -*- !#
;; Copyright (c) 2020 Travis Hinkelman
;; SPDX-License-Identifier: MIT
#!r6rs

(import (rnrs (6))
        (srfi :64 testing)
        (chez-docs))

(test-begin "fuzzy-test")
(test-equal '("append" "append!" "and" "apply" "cond") (find-proc "append" 'fuzzy 5))
(test-equal '("hashtable?" "hash-table?" "mutable") (find-proc "hashtable" 'fuzzy 3))
(test-equal '("hash-table?" "hashtable?" "eq-hashtable?") (find-proc "hash-table?" 'fuzzy 3))
(test-equal '("read" "and" "cadr" "car" "cd") (find-proc "head" 'fuzzy 5))
(test-equal '("map" "max" "*" "+" "-") (find-proc "map" 'fuzzy 5))
(test-end "fuzzy-test")

(test-begin "partial-match-test")
(test-equal '("list-sort" "sort" "sort!" "vector-sort" "vector-sort!") (find-proc "sort"))
(test-equal '("hash-table?") (find-proc "hash-table?" 'exact 3))
(test-equal '("list-head" "lookahead-char" "lookahead-u8" "make-boot-header") (find-proc "head" 'exact 5))
(test-equal '("append" "append!" "string-append") (find-proc "append"))
(test-equal '("andmap" "hash-table-map" "map" "ormap" "vector-map") (find-proc "map"))
(test-end "partial-match-test")

(test-begin "starts-with-test")
(test-equal '("map") (find-proc "^map"))
(test-equal '("hash-table-for-each" "hash-table-map" "hash-table?" "hashtable-cell") (find-proc "^hash" 'exact 4))
(test-equal '("fl*" "fl+" "fl-") (find-proc "^fl" 'exact 3))
(test-end "starts-with-test")

(exit (if (zero? (test-runner-fail-count (test-runner-get))) 0 1))
