#!/usr/bin/env scheme-script
;; -*- mode: scheme; coding: utf-8 -*- !#
;; Copyright (c) 2020 Travis Hinkelman
;; SPDX-License-Identifier: MIT
#!r6rs

(import (rnrs (6))
        (only (chezscheme) library-directories with-output-to-string)
        (srfi :64 testing)
        (chez-docs))

;; helpers ------------------------------------------------------

(define (string-prefix? prefix s)
  (and (<= (string-length prefix) (string-length s))
       (string=? prefix (substring s 0 (string-length prefix)))))

(define (string-suffix? suffix s)
  (let ([n (string-length s)]
        [m (string-length suffix)])
    (and (<= m n) (string=? suffix (substring s (- n m) n)))))

(define (string-contains? s pattern)
  (let ([n (string-length s)]
        [m (string-length pattern)])
    (let loop ([i 0])
      (cond [(> (+ i m) n) #f]
            [(string=? pattern (substring s i (+ i m))) #t]
            [else (loop (+ i 1))]))))

;; index of first occurrence of pattern in s, or #f
(define (string-index-of s pattern)
  (let ([n (string-length s)]
        [m (string-length pattern)])
    (let loop ([i 0])
      (cond [(> (+ i m) n) #f]
            [(string=? pattern (substring s i (+ i m))) i]
            [else (loop (+ i 1))]))))

;; the data files are not exported by (chez-docs) so read them from
;; the same directory that the library is found in
(define (find-data-file file)
  (let loop ([dirs (append (map car (library-directories)) '("."))])
    (cond [(null? dirs)
           (error 'find-data-file "file not found in library-directories" file)]
          [(file-exists? (string-append (car dirs) "/" file))
           (string-append (car dirs) "/" file)]
          [else (loop (cdr dirs))])))

;; data files have the form (define name (quote data))
(define (read-data-file file)
  (let ([form (call-with-input-file (find-data-file file) read)])
    (cadr (caddr form))))

(define summary-data (read-data-file "summary-data.scm"))
(define chez-docs-data (read-data-file "chez-docs-data.scm"))

(define (summary-rows source) (cdr (assoc source summary-data)))
(define (doc-anchors source) (map car (cdr (assoc source chez-docs-data))))

;; rows in summary-data whose anchor has no entry in chez-docs-data
(define (missing-anchors source)
  (let ([anchors (doc-anchors source)])
    (map car (filter (lambda (row) (not (member (cadr row) anchors)))
                     (summary-rows source)))))

;; rows whose url does not end in page.html#./anchor
(define (mismatched-urls source)
  (map car
       (filter (lambda (row)
                 (let* ([anchor (cadr row)]
                        [url (caddr row)]
                        [colon (string-index-of anchor ":")]
                        [page (if colon (substring anchor 0 colon) anchor)])
                   (not (string-suffix?
                         (string-append page ".html#./" anchor) url))))
               (summary-rows source))))

;; everything before the page name in each url, e.g., ".../csug10.3.0/"
(define (url-prefixes source)
  (let loop ([rows (summary-rows source)]
             [results '()])
    (if (null? rows)
        results
        (let* ([url (caddr (car rows))]
               [page-start (let find ([i (- (string-length url) 1)]
                                      [slashes 0])
                             (if (char=? (string-ref url i) #\/)
                                 (if (= slashes 1) (+ i 1) (find (- i 1) 1))
                                 (find (- i 1) slashes)))]
               [prefix (substring url 0 page-start)])
          (loop (cdr rows)
                (if (member prefix results) results (cons prefix results)))))))

(define (doc-output . args)
  (with-output-to-string (lambda () (apply doc args))))

(define (error-message thunk)
  (guard (c [(message-condition? c) (condition-message c)])
    (thunk)
    #f))

;; find-proc ----------------------------------------------------

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
(test-equal '("append" "append!" "immutable-vector-append" "string-append"
              "string-append-immutable" "vector-append") (find-proc "append"))
(test-equal '("andmap" "hash-table-map" "map" "ormap" "vector-map") (find-proc "map"))
(test-end "partial-match-test")

(test-begin "starts-with-test")
(test-equal '("map") (find-proc "^map"))
(test-equal '("hash-table-for-each" "hash-table-map" "hash-table?" "hashtable-cell") (find-proc "^hash" 'exact 4))
(test-equal '("fl*" "fl+" "fl-") (find-proc "^fl" 'exact 3))
(test-end "starts-with-test")

(test-begin "find-proc-edge-cases-test")
(test-equal '() (find-proc "zzzqqq"))
(test-equal '() (find-proc "zzzqqq" 'exact 3))
(test-equal '() (find-proc "map" 'exact 0))
(test-equal '() (find-proc "map" 'fuzzy 0))
(test-equal 3 (length (find-proc "zzzqqq" 'fuzzy 3)))
(test-error (find-proc ""))
(test-end "find-proc-edge-cases-test")

;; data integrity -----------------------------------------------

(test-begin "data-integrity-test")
;; every summary row should have documentation text
(test-equal '() (missing-anchors 'csug))
(test-equal '() (missing-anchors 'tspl))
;; urls should point to the page and anchor named in the row
(test-equal '() (mismatched-urls 'csug))
(test-equal '() (mismatched-urls 'tspl))
;; all urls for a source should point to the same version of the docs
(test-equal 1 (length (url-prefixes 'csug)))
(test-equal 1 (length (url-prefixes 'tspl)))
(test-equal '("https://cisco.github.io/ChezScheme/csug10.3.0/")
  (url-prefixes 'csug))
;; guard against a scrape that silently returns little or nothing
(test-assert (> (length (summary-rows 'csug)) 1000))
(test-assert (> (length (summary-rows 'tspl)) 700))
(test-assert (assoc "current-date" (summary-rows 'csug)))
(test-assert (assoc "load-shared-object" (summary-rows 'csug)))
(test-assert (assoc "car" (summary-rows 'tspl)))
(test-assert (assoc "define-record-type" (summary-rows 'tspl)))
(test-end "data-integrity-test")

;; doc ----------------------------------------------------------

(test-begin "doc-display-test")
(let ([out (doc-output "current-date" 'display 'csug)])
  (test-assert (string-prefix? "\nCHEZ SCHEME USER'S GUIDE\n\n" out))
  (test-assert (string-contains? out "procedure: (current-date)"))
  (test-assert (not (string-contains? out "THE SCHEME PROGRAMMING LANGUAGE"))))
(let ([out (doc-output "car" 'display 'tspl)])
  (test-assert (string-prefix? "\nTHE SCHEME PROGRAMMING LANGUAGE\n\n" out))
  (test-assert (string-contains? out "(car pair)")))
;; action and source default to 'display and 'both
(test-equal (doc-output "car" 'display 'tspl) (doc-output "car"))
;; "<" is documented in both sources; csug is displayed first
(let* ([out (doc-output "<" 'display 'both)]
       [csug-pos (string-index-of out "CHEZ SCHEME USER'S GUIDE")]
       [tspl-pos (string-index-of out "THE SCHEME PROGRAMMING LANGUAGE")])
  (test-assert (and csug-pos tspl-pos (< csug-pos tspl-pos))))
(test-equal (doc-output "<") (doc-output "<" 'display 'both))
(test-end "doc-display-test")

;; errors -------------------------------------------------------

(test-begin "error-test")
(test-error (doc 'car))
(test-error (doc "car" 'show))
(test-error (doc "car" 'display 'r6rs))
(test-error (find-proc 'map))
(test-error (find-proc "map" 'regex))
;; not found in the requested source
(test-error (doc "current-date" 'display 'tspl))
(test-error (doc "not-a-real-proc"))
;; unknown names suggest the closest match
(test-assert (string-contains? (error-message (lambda () (doc "carr")))
                               "Did you mean '"))
(test-assert (string-contains? (error-message (lambda () (doc "carr" 'display 'csug)))
                               "not found in csug"))
(test-end "error-test")

(exit (if (zero? (test-runner-fail-count (test-runner-get))) 0 1))
