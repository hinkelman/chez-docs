(library (chez-docs)
  (export doc
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
    (let ([srclu '((csug "\nCHEZ SCHEME USER'S GUIDE\n\n")
                   (tspl "\nTHE SCHEME PROGRAMMING LANGUAGE\n\n"))])
      (when (not (symbol=? action 'open))
        (display (cadr (assoc source srclu)))
        (for-each display doc))
      (when (not (symbol=? action 'display))
        (launch-doc-link proc source))))

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
    (system (string-append open-string (get-url proc source))))

  (define (launch-csug-summary)
    (system
     (string-append
      open-string
      "https://cisco.github.io/ChezScheme/csug10.0/summary.html")))

  (define open-string
    (case (machine-type)
      [(i3nt ti3nt a6nt ta6nt) "start "]     ; windows
      [(i3osx ti3osx a6osx ta6osx) "open "]  ; mac
      [else "xdg-open "]))                   ; linux

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

