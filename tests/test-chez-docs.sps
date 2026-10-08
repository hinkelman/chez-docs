#!/usr/bin/env scheme-script
;; -*- mode: scheme; coding: utf-8 -*- !#
;; Copyright (c) 2020 Travis Hinkelman
;; SPDX-License-Identifier: MIT
#!r6rs

(import (rnrs (6))
        (only (chezscheme) library-directories with-output-to-string
              parameterize putenv)
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

;; rendering ----------------------------------------------------

(test-begin "doc-render-test")
;; every entry is (anchor para ...) and every para is a non-empty list of nodes
(test-assert
 (for-all (lambda (source)
            (for-all (lambda (entry)
                       (and (string? (car entry))
                            (pair? (cdr entry))
                            (for-all pair? (cdr entry))))
                     (cdr (assoc source chez-docs-data))))
          '(csug tspl)))
;; code, var, and bold markup render as plain text; paragraphs end in a blank line
(test-assert
 (string-prefix?
  (string-append
   "\nTHE SCHEME PROGRAMMING LANGUAGE\n\n"
   "syntax: (quote obj)\nsyntax: 'obj\nreturns: obj\nlibraries: (rnrs base), (rnrs)\n\n"
   "'obj is equivalent to (quote obj). The abbreviated form is converted into "
   "the longer form by the Scheme reader (see read).\n\n")
  (doc-output "quote" 'display 'tspl)))
;; math nodes render their text
(test-assert (string-contains? (doc-output "quote" 'display 'tspl) "(+ 2 3) => 5\n"))
;; list items render with a bullet
(test-assert (string-contains? (doc-output "continuation-marks->iterator" 'display 'csug)
                               "\n* The first result is"))
;; tables are laid out in aligned columns with trimmed cells
(test-assert (string-contains? (doc-output "eval-when" 'display 'csug)
                               (string-append
                                "\n\n   load  compile  visit  revisit  eval\n"
                                "L  L     C        V      R        ---\n"
                                "C  ---   ---      ---    ---      C\n")))
;; the plain style keeps ASCII symbols in tables
(test-assert (string-contains? (doc-output "ee-bind-key" 'display 'csug)
                               "\n      <key-string>  -->  \"<key-char>^+\"\n"))
(test-assert (not (string-contains? (doc-output "define-record" 'display 'csug)
                                    "[table not shown]")))
(test-end "doc-render-test")

(test-begin "doc-style-test")
(test-equal 'plain (doc-style))
(test-error (doc-style 'fancy))
(test-equal 'plain (doc-style))
;; doc-style is a parameter, so parameterize leaves the global setting alone
(define (rich-output . args)
  (parameterize ([doc-style 'rich]) (apply doc-output args)))
(define esc (string (integer->char 27)))
(let ([out (rich-output "quote" 'display 'tspl)])
  ;; bold labels, cyan code, italic metavariables
  (test-assert (string-contains? out (string-append esc "[0;1msyntax" esc "[0m")))
  (test-assert (string-contains? out (string-append esc "[0;36m(quote " esc "[0;36;3mobj")))
  ;; the italic metavariable returns to the enclosing code style, not to no style
  (test-assert (string-contains? out (string-append "obj" esc "[0;36m)" esc "[0m")))
  ;; => becomes a Unicode arrow
  (test-assert (string-contains? out "(+ 2 3) \x21D2; 5\n")))
(test-assert (not (string-contains? (doc-output "quote" 'display 'tspl) esc)))
;; Unicode subscripts and bullets
(test-assert (string-contains? (rich-output "eq?" 'display 'tspl) "obj\x2081;"))
(test-assert (string-contains? (rich-output "continuation-marks->iterator" 'display 'csug)
                               "\n\x2022; The first result is"))
;; superscripts with a Unicode form map; others fall back to parenthesized ^(...)
(test-assert (string-contains? (rich-output "foreign-free" 'display 'csug)
                               "2\x2B7;\x207B;\xB9;"))
;; NO_COLOR keeps Unicode but drops escape codes
(putenv "NO_COLOR" "1")
(let ([out (rich-output "quote" 'display 'tspl)])
  (test-assert (not (string-contains? out esc)))
  (test-assert (string-contains? out "(+ 2 3) \x21D2; 5\n")))
;; checked without color because size is an italic metavariable
(test-assert (string-contains? (rich-output "bytevector-sint-set!" 'display 'tspl)
                               "2^(size\xB7;8-1)"))
;; an indented table is indented on every row
(test-assert (string-contains? (rich-output "ee-bind-key" 'display 'csug)
                               (string-append
                                "\n      <key-char>  \x27F6;  \\\\e (specifying an escape character)\n"
                                "                  |  ^x (specifying control-x)\n")))
;; links are plain text without color
(test-assert (string-contains? (rich-output "define-top-level-syntax" 'display 'csug)
                               "(Section 12.3"))
(putenv "NO_COLOR" "")
(test-assert (string-contains? (rich-output "quote" 'display 'tspl) esc))
;; links become OSC 8 hyperlinks resolved against the book's base url
(let ([osc8 (lambda (url text)
              (string-append esc "]8;;" url esc "\\" text esc "]8;;" esc "\\"))])
  (test-assert (string-contains? (rich-output "define-top-level-syntax" 'display 'csug)
                                 (osc8 "https://cisco.github.io/ChezScheme/csug10.3.0/system.html#g119"
                                       "12.3")))
  ;; "http://scheme.com/tspl4/./syntax.html" in the data loses its "/./"
  (test-assert (string-contains? (rich-output "define-structure" 'display 'csug)
                                 (osc8 "http://scheme.com/tspl4/syntax.html#g137" "8.4"))))
;; the plain style has no hyperlinks
(test-assert (string-contains? (doc-output "define-top-level-syntax" 'display 'csug)
                               "(Section 12.3"))
(test-end "doc-style-test")

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
;; names documented only in the other book say where they are found
(test-equal "fxsll not found in tspl but is found in csug"
  (error-message (lambda () (doc "fxsll" 'display 'tspl))))
(test-equal "named let not found in csug but is found in tspl"
  (error-message (lambda () (doc "named let" 'display 'csug))))
(test-end "error-test")

(exit (if (zero? (test-runner-fail-count (test-runner-get))) 0 1))
