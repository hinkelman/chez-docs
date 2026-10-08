(library (chez-docs)
  (export doc
          doc-style
          find-proc
          launch-csug-summary)

  (import (chezscheme))

  ;; setup --------------------------------------------------
  ;; https://gitlab.com/akkuscm/akku/-/issues/49#note_343046504
  ;; Chez has `include` so didn't need macro in GitLab issue example
  ;; `include` is much simpler than the hoops that I was jumping through previously
  (include "summary-data.scm")
  (include "chez-docs-data.scm")
  ;; many of these procedures use this data without it being explicitly passed

  ;; https://stackoverflow.com/questions/8382296/scheme-remove-duplicated-numbers-from-list
  (define (remove-duplicates ls)
    (cond [(null? ls)
           '()]
          [(member (car ls) (cdr ls))
           (remove-duplicates (cdr ls))]
          [else
           (cons (car ls) (remove-duplicates (cdr ls)))]))

  ;; show documentation -----------------------------------------

  (define doc
    (case-lambda
      [(proc) (doc-helper proc 'display 'both)]
      [(proc action) (doc-helper proc action 'both)]
      [(proc action source) (doc-helper proc action source)]))

  (define (doc-helper proc action source)
    (unless (string? proc)
      (assertion-violation "(doc proc)" "proc is not a string"))
    (unless (member action '(display open both))
      (assertion-violation "(doc proc action)"
                           "action not one of 'display, 'open, 'both"))
    (cond [(or (symbol=? source 'csug) (symbol=? source 'tspl))
           (let ([doc (get-doc proc source)])
             (if doc
                 (action-helper proc doc action source)
                 (assertion-violation "(doc proc action source)"
                                      (string-append
                                       proc " not found in "
                                       (symbol->string source) "\n"
                                       (guess-proc proc)))))]
          [(symbol=? source 'both)
           (let ([doc-csug (get-doc proc 'csug)]
                 [doc-tspl (get-doc proc 'tspl)])
             (if (or doc-csug doc-tspl)
                 (begin 
                   (when doc-csug (action-helper proc doc-csug action 'csug))
                   (when doc-tspl (action-helper proc doc-tspl action 'tspl)))
                 (assertion-violation "(doc proc)"
                                      (string-append
                                       proc " not found in csug or tspl\n"
                                       (guess-proc proc)))))]
          [else
           (assertion-violation "(doc proc action source)"
                                "source not one of 'csug, 'tspl, 'both")]))

  (define (action-helper proc doc action source)
    (let ([srclu '((csug "CHEZ SCHEME USER'S GUIDE")
                   (tspl "THE SCHEME PROGRAMMING LANGUAGE"))])
      (when (not (symbol=? action 'open))
        (let ([render (current-renderer)])
          (display (string-append "\n" (render (list (list 'bold (cadr (assoc source srclu)))))
                                  "\n\n"))
          (for-each (lambda (para) (display (string-append (render para) "\n\n"))) doc)))
      (when (not (symbol=? action 'display))
        (launch-doc-link proc source))))

  ;; render documentation -----------------------------------------
  ;; each doc is a list of paragraphs; each paragraph is a list of nodes
  ;; a node is either a string or one of:
  ;;   (code node ...) (var node ...) (bold node ...) (sub node ...)
  ;;   (sup node ...) (link href node ...) (math string) (br)
  ;;   (ul node ...) (li node ...) (dt node ...) (dd node ...)
  ;;   (table (row (cell node ...) ...) ...)
  ;; see sxml->doc in chez-docs-scrape for how these are produced

  ;; 'plain renders ASCII text only
  ;; 'rich adds Unicode symbols (=> as ⇒, subscripts, bullets) and ANSI styling
  ;; (bold labels, italic metavariables, colored code); ANSI styling is
  ;; omitted when the NO_COLOR environment variable is set (https://no-color.org)
  (define doc-style
    (make-parameter
     'plain
     (lambda (x)
       (unless (memq x '(plain rich))
         (assertion-violation "(doc-style style)" "style not one of 'plain, 'rich" x))
       x)))

  (define (current-renderer)
    (if (symbol=? (doc-style) 'rich)
        (make-renderer #t (not (no-color?)))
        (make-renderer #f #f)))

  (define (no-color?)
    (let ([nc (getenv "NO_COLOR")])
      (and nc (not (string=? nc "")))))

  ;; SGR codes for styled nodes
  (define sgr-codes
    '((bold . "1")
      (var  . "3")      ; italic
      (code . "36")))   ; cyan

  ;; returns a procedure that renders a list of nodes to a string
  ;; rich?: use Unicode symbols; color?: emit ANSI escape codes
  (define (make-renderer rich? color?)
    ;; state is the list of active SGR codes (innermost first); every style
    ;; change re-emits the full state so nested styles survive a closing tag
    (define (sgr state)
      (cond [(not color?) ""]
            [(null? state) "\x1b;[0m"]
            [else (string-append "\x1b;[0;" (join (reverse state) ";") "m")]))
    (define (styled tag kids state)
      (let ([code (cdr (assq tag sgr-codes))])
        (if color?
            (let ([new (cons code state)])
              (string-append (sgr new) (render-nodes kids new) (sgr state)))
            (render-nodes kids state))))
    (define (render-node node state)
      (cond
       [(string? node) node]
       [(pair? node)
        (let ([kids (cdr node)])
          (case (car node)
            [(br) "\n"]
            [(table) "[table not shown]"]
            [(link) (render-nodes (cdr kids) state)]
            [(ul) (string-append "\n" (render-nodes kids state) "\n")]
            [(li) (string-append (if rich? "\n\x2022; " "\n* ") (render-nodes kids state))]
            [(dt) (string-append "\n" (render-nodes kids state))]
            [(dd) (string-append "\n    " (render-nodes kids state))]
            [(sup) (or (and rich? (script-text kids superscripts))
                       (let ([s (render-nodes kids state)])
                         ;; parenthesize so 2^(size·8-1) - 1 isn't ambiguous
                         (if (and rich? (> (string-length (node-text kids)) 1))
                             (string-append "^(" s ")")
                             (string-append "^" s))))]
            [(sub) (or (and rich? (script-text kids subscripts))
                       (render-nodes kids state))]
            [(math) (let ([s (car kids)])
                      (if rich?
                          (let ([hit (assoc s math-symbols)]) (if hit (cdr hit) s))
                          s))]
            [(code var bold) (styled (car node) kids state)]
            [else (render-nodes kids state)]))]
       [else ""]))
    (define (render-nodes nodes state)
      (apply string-append (map (lambda (n) (render-node n state)) nodes)))
    (lambda (nodes) (render-nodes nodes '())))

  (define (join strs sep)
    (if (null? strs)
        ""
        (fold-left (lambda (acc s) (string-append acc sep s)) (car strs) (cdr strs))))

  ;; maps all text in nodes through table, or #f if any char has no mapping
  ;; (e.g., the "·" in 2^(size·8)), in which case the caller falls back to plain
  (define (script-text nodes table)
    (let ([chars (string->list (node-text nodes))])
      (and (pair? chars)
           (for-all (lambda (c) (assv c table)) chars)
           (list->string (map (lambda (c) (cdr (assv c table))) chars)))))

  (define (node-text nodes)
    (apply string-append
           (map (lambda (n)
                  (cond [(string? n) n]
                        [(pair? n) (node-text (cdr n))]
                        [else ""]))
                nodes)))

  (define (char-table from to)
    (map cons (string->list from) (string->list to)))

  (define subscripts
    (char-table "0123456789+-=()aehijklmnoprstuvx"
                "\x2080;\x2081;\x2082;\x2083;\x2084;\x2085;\x2086;\x2087;\x2088;\x2089;\x208A;\x208B;\x208C;\x208D;\x208E;\x2090;\x2091;\x2095;\x1D62;\x2C7C;\x2096;\x2097;\x2098;\x2099;\x2092;\x209A;\x1D63;\x209B;\x209C;\x1D64;\x1D65;\x2093;"))

  (define superscripts
    (char-table "0123456789+-=()abcdefghijklmnoprstuvwxyz"
                "\x2070;\xB9;\xB2;\xB3;\x2074;\x2075;\x2076;\x2077;\x2078;\x2079;\x207A;\x207B;\x207C;\x207D;\x207E;\x1D43;\x1D47;\x1D9C;\x1D48;\x1D49;\x1DA0;\x1D4D;\x2B0;\x2071;\x2B2;\x1D4F;\x2E1;\x1D50;\x207F;\x1D52;\x1D56;\x2B3;\x2E2;\x1D57;\x1D58;\x1D5B;\x2B7;\x2E3;\x2B8;\x1DBB;"))

  (define math-symbols
    '(("=>"  . "\x21D2;")    ; ⇒
      ("->"  . "\x2192;")    ; →
      ("-->" . "\x27F6;")    ; ⟶
      ("<="  . "\x2264;")    ; ≤
      (">="  . "\x2265;")))  ; ≥

  (define (get-doc proc source)
    (let* ([anchor (get-anchor proc source)]
           [src-data (cdr (assoc source chez-docs-data))]
           [doc (assoc anchor src-data)])
      (if doc (cdr doc) doc)))
  
  (define (get-anchor proc source)
    (let* ([src-data (cdr (assoc source summary-data))]
           [row (assoc proc src-data)])
      (if row (cadr row) row)))

  (define (get-url proc source)
    (let* ([src-data (cdr (assoc source summary-data))]
           [row (assoc proc src-data)])
      (if row (caddr row) row)))

  (define (launch-doc-link proc source)
    (launch-link
     (get-url proc source)
     "(doc proc action)"
     "documentation"))

  (define (launch-csug-summary)
    (launch-link
     "https://cisco.github.io/ChezScheme/csug10.3.0/summary.html"
     "(launch-csug-summary)"
     "CSUG summary"))

  (define (launch-link url proc-string link-desc)
    (if (not (string=? open-string "undefined"))
	(system (string-append open-string url))
	(assertion-violation
	 proc-string
	 (string-append
	  "open command not defined for this machine type\n"
	  link-desc " is at " url))))

  (define open-string
    (case (machine-type)
      ;; windows
      [(i3nt ti3nt a6nt ta6nt arm64nt tarm64nt)
       "start "]   
      ;; mac
      [(i3osx ti3osx a6osx ta6osx arm64osx tarm64osx ppc32osx tppc32osx)
       "open "]  
      ;; linux
      [(i3le ti3le a6le ta6le arm64le tarm64le arm32le tarm32le
	     rv64le trv64le la64le tla64le ppc32le tppc32le)
       "xdg-open "]                      
      [else "undefined"]))                   

  ;; procedure search -----------------------------------------

  ;; extract unique list of "procedures" from data
  (define proc-list
    (sort string<?
          (remove-duplicates
           (append
            (map car (cdr (assoc 'csug summary-data)))      
            (map car (cdr (assoc 'tspl summary-data)))))))

  (define (guess-proc proc)
    (string-append "Did you mean '" (car (find-proc proc 'fuzzy)) "'?"))

  (define find-proc
    (case-lambda
      [(search-string)
       (find-proc-helper search-string 'exact 10)]
      [(search-string search-type)
       (find-proc-helper search-string search-type 10)]
      [(search-string search-type max-results)
       (find-proc-helper search-string search-type max-results)]))

  (define (find-proc-helper search-string search-type max-results)
    (unless (string? search-string)
      (assertion-violation "(find-proc search-string)" "search-string is not a string"))
    (cond [(symbol=? search-type 'fuzzy)
           (let* ([dist-list (map (lambda (x) (lev search-string x))
                                  proc-list)]
                  [dist-proc (map (lambda (dist proc) (cons dist proc))
                                  dist-list proc-list)]
                  [dist-proc-sort (sort (lambda (x y) (< (car x) (car y)))
                                        dist-proc)])
             (prepare-results dist-proc-sort search-type max-results))]
          [(symbol=? search-type 'exact)
           (let* ([bool-list (map (lambda (x) (string-match search-string x))
                                  proc-list)]
                  [bool-proc (map (lambda (bool proc) (cons bool proc))
                                  bool-list proc-list)]
                  [bool-proc-filter (filter (lambda (x) (car x)) bool-proc)])
             (prepare-results bool-proc-filter search-type max-results))]
          [else
           (assertion-violation "(find-proc search-string search-type)"
                                "search-type must be either 'exact or 'fuzzy")]))

  (define (prepare-results ls search-type max-results)
    (let* ([len (length ls)]
           [max-n (if (> max-results len) len max-results)])
      (when (and (symbol=? search-type 'exact) (> len max-results))
        (display (string-append "Returning " (number->string max-results)
                                " of " (number->string len)
                                " results\n")))
      (map cdr (list-head ls max-n))))

  (define (string-match s t)
    (let* ([s-list (string->list s)]
           [t-list (string->list t)])
      (if (char=? (car s-list) #\^)
          (string-match-helper (cdr s-list) t-list)
          (not (for-all (lambda (x) (equal? x #f))
                        (map (lambda (t-sub) (string-match-helper s-list t-sub))
                             (potential-matches (car s-list) t-list)))))))

  (define (string-match-helper s-list t-list)
    (cond [(not t-list) #f] 
          [(null? s-list) #t]
          [(< (length t-list) (length s-list)) #f]
          [(char=? (car s-list) (car t-list))
           (string-match-helper (cdr s-list) (cdr t-list))]
          [else #f]))

  (define (potential-matches char t-list)
    (let loop ([t-list t-list]
               [results '()])
      (if (null? t-list)
          (remove-duplicates (reverse results))
          (loop (cdr t-list) (cons (member char t-list) results)))))
  
  ;; https://blogs.mathworks.com/cleve/2017/08/14/levenshtein-edit-distance-between-strings/
  (define (lev s t)
    (let* ([s (list->vector (string->list s))]
           [t (list->vector (string->list t))]
           [m (vector-length s)]
           [n (vector-length t)]
           [x (list->vector (iota (add1 n)))]
           [y (list->vector (make-list (add1 n) 0))])
      (do ((i 0 (add1 i)))
          ((= i m))
        (vector-set! y 0 i)
        (do ((j 0 (add1 j)))
            ((= j n))
          (let ([c (if (char=? (vector-ref s i) (vector-ref t j)) 0 1)])
            (vector-set! y (add1 j) (min (add1 (vector-ref y j))
                                         (add1 (vector-ref x (add1 j)))
                                         (+ c  (vector-ref x j))))))
        ;; swap x and y
        (let ([tmp x])
          (set! x y)
          (set! y tmp)))
      (vector-ref x n)))
  )

