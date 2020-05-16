(library (chez-docs)
  (export doc
          find-proc
          launch-csug-summary)

  (import (chezscheme))

  ;; load and prep data --------------------------------------------------
  ;; https://gitlab.com/akkuscm/akku/-/issues/49#note_343046504
  ;; Chez has include so didn't need macro in GitLab issue example
  ;; include is much simpler than the hoops that I was jumping through previously
  (include "chez-docs-data.scm")

  ;; https://stackoverflow.com/questions/8382296/scheme-remove-duplicated-numbers-from-list
  (define (remove-duplicates ls)
    (cond [(null? ls)
           '()]
          [(member (car ls) (cdr ls))
           (remove-duplicates (cdr ls))]
          [else
           (cons (car ls) (remove-duplicates (cdr ls)))]))

  ;; extract unique list of "procedures" from data
  (define proc-list
    (sort string<?
          (remove-duplicates
           (append
            (map car (cdr (assoc 'csug data)))      
            (map car (cdr (assoc 'tspl data))))))) 

  ;; launch documentation -----------------------------------------

  (define doc
    (case-lambda
      [(proc) (doc-helper proc 'open-link 'both)]
      [(proc action) (doc-helper proc action 'both)]
      [(proc action source) (doc-helper proc action source)]))

  (define (doc-helper proc action source)
    (unless (or (symbol=? action 'open-link)
                (symbol=? action 'display-form))
      (assertion-violation "(doc proc action)" "action not one of 'open-link or 'display-form"))
    (let loop ([ls (data-lookup proc source)])
      (cond [(null? ls) (void)]
            [else
             (display-form-open (car ls) action)
             (loop (cdr ls))])))

  (define (display-form-open data-selected action)
    (when data-selected
      (display (replace-tilde (string-append (cadr data-selected) "\n")))
      (when (symbol=? action 'open-link)
        (system (string-append open-string (caddr data-selected))))))

  (define (data-lookup proc source)
    (cond [(or (symbol=? source 'csug) (symbol=? source 'tspl))
           (let ([result (dl-helper proc source)])
             (if result
                 (list result)
                 (assertion-violation "(doc proc action source)"
                                      (string-append proc " not found in " (symbol->string source)))))]
          [(symbol=? source 'both)
           (let ([csug (dl-helper proc 'csug)]
                 [tspl (dl-helper proc 'tspl)])
             (if (or csug tspl)
                 (list csug tspl)
                 (assertion-violation "(doc proc)" (string-append proc " not found in csug or tspl"))))]
          [else
           (assertion-violation "(doc proc action source)" "source not one of 'csug, 'tspl, 'both")]))

  ;; extract form and url for selected proc and source
  (define (dl-helper proc source)
    (assoc proc (cdr (assoc source data)))) 

  (define (replace-tilde str)
    (let* ([in (open-input-string str)]
           [str-list (string->list str)])
      (if (not (member #\~ str-list))
          str  ;; return string unchanged b/c no tilde
          (let loop ([c (read-char in)]
                     [result ""])
            (cond [(eof-object? c)
                   result]
                  [(char=? c #\~)
                   (loop (read-char in) (string-append result "\n"))]
                  [else
                   (loop (read-char in) (string-append result (string c)))])))))

  (define (launch-csug-summary)
    (system (string-append open-string "https://cisco.github.io/ChezScheme/csug9.5/summary.html#./summary:h0")))

  (define open-string
    (case (machine-type)
      [(i3nt ti3nt a6nt ta6nt) "start "]     ; windows
      [(i3osx ti3osx a6osx ta6osx) "open "]  ; mac
      [else "xdg-open "]))                   ; linux

  ;; procedure search -----------------------------------------

  (define find-proc
    (case-lambda
      [(search-string) (find-proc-helper search-string 'exact 10)]
      [(search-string search-type) (find-proc-helper search-string search-type 10)]
      [(search-string search-type max-results) (find-proc-helper search-string search-type max-results)]))

  (define (find-proc-helper search-string search-type max-results)
    (unless (string? search-string)
      (assertion-violation "(find-proc search-string)" "search-string is not a string"))
    (cond [(symbol=? search-type 'fuzzy)
           (let* ([dist-list (map (lambda (x) (lev search-string x)) proc-list)]
                  [dist-proc (map (lambda (dist proc) (cons dist proc)) dist-list proc-list)]
                  [dist-proc-sort (sort (lambda (x y) (< (car x) (car y))) dist-proc)])
             (prepare-results dist-proc-sort max-results))]
          [(symbol=? search-type 'exact)
           (let* ([bool-list (map (lambda (x) (string-match search-string x)) proc-list)]
                  [bool-proc (map (lambda (bool proc) (cons bool proc)) bool-list proc-list)]
                  [bool-proc-filter (filter (lambda (x) (car x)) bool-proc)])
             (prepare-results bool-proc-filter max-results))]
          [else
           (assertion-violation "(find-proc search-string search-type)"
                                "search-type must be either 'exact or 'fuzzy")]))

  (define (prepare-results ls max-results)
    (let* ([len (length ls)]
           [max-n (if (> max-results len) len max-results)])
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

