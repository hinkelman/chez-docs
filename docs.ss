(library (chez-docs docs)
  (export doc
          find-proc
          launch-csug-summary)

  (import (chezscheme))

  ;; load data --------------------------------------------------

  (define data-paths
    (map (lambda (x) (string-append x "/chez-docs/data.scm"))
         (map car (library-directories))))
  
  (define data
    (let ([tmp '()])
      (for-each
       (lambda (path)
         (when (file-exists? path)
           (set! tmp (with-input-from-file path read))))
       data-paths)
      tmp))

  ;; https://stackoverflow.com/questions/8382296/scheme-remove-duplicated-numbers-from-list
  (define (remove-duplicates ls)
    (cond [(null? ls)
           '()]
          [(member (car ls) (cdr ls))
           (remove-duplicates (cdr ls))]
          [else
           (cons (car ls) (remove-duplicates (cdr ls)))]))

  (define proc-list
    (sort string<?
          (remove-duplicates
           (append
            (map car (cadar data))     ;; csug procs
            (map car (cadadr data)))))) ;; tspl procs

  ;; launch documentation -----------------------------------------

  (define doc
    (case-lambda
      [(proc) (doc-helper proc "both" #t)]
      [(proc source) (doc-helper proc source #t)]
      [(proc source launch?) (doc-helper proc source launch?)]))

  (define (doc-helper proc source launch?)
    (define (loop ls)
      (cond [(null? ls) (void)]
            [else
             (display-launch (car ls) launch?)
             (loop (cdr ls))]))
    (loop (data-lookup proc source)))

  (define (display-launch data-selected launch?)
    (when data-selected
      (display (replace-tilde (string-append (caadr data-selected) "\n")))
      (when launch?
        (system (string-append open-string (cadadr data-selected))))))

  (define (data-lookup proc source)
    (cond [(or (string=? source "CSUG") (string=? source "TSPL"))
           (list (dl-helper proc source))]
          [(string=? source "both")
           (let ([csug (dl-helper proc "CSUG")]
                 [tspl (dl-helper proc "TSPL")])
             (if (or csug tspl)
                 (list csug tspl)
                 (assertion-violation "(doc proc)" "proc not found")))]
          [else
           (assertion-violation "(doc proc source)" "source not one of CSUG, TSPL, both")]))

  ;; data is imported above
  (define (dl-helper proc source)
    (assoc proc (cadr (assoc source data)))) 

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
      [(search-string) (find-proc-helper search-string 10 #f)]
      [(search-string max-results) (find-proc-helper search-string max-results #f)]
      [(search-string max-results fuzzy?) (find-proc-helper search-string max-results fuzzy?)]))

  (define (find-proc-helper search-string max-results fuzzy?)
    (unless (string? search-string)
      (assertion-violation "(find-proc search-string)" "search-string is not a string"))
    (cond [fuzzy?
           (let* ([dist-list (map (lambda (x) (lev search-string x)) proc-list)]
                  [dist-proc (map (lambda (dist proc) (cons dist proc)) dist-list proc-list)]
                  [dist-proc-sort (sort (lambda (x y) (< (car x) (car y))) dist-proc)])
             (prepare-results dist-proc-sort max-results))]
          [else
           (let* ([bool-list (map (lambda (x) (string-match search-string x)) proc-list)]
                  [bool-proc (map (lambda (bool proc) (cons bool proc)) bool-list proc-list)]
                  [bool-proc-filter (filter (lambda (x) (car x)) bool-proc)])
             (prepare-results bool-proc-filter max-results))]))

  (define (prepare-results ls max-results)
    (let* ([len (length ls)]
           [max-n (if (> max-results len) len max-results)])
      (map cdr (list-head ls max-n))))

  (define (string-match s t)
    (define (loop s-list t-sub)
      (cond [(null? s-list) #t]
            [(< (length t-sub) (length s-list)) #f]
            [(char=? (car s-list) (car t-sub))
             (loop (cdr s-list) (cdr t-sub))]
            [else #f]))
    (let* ([s-list-temp (string->list s)]
           [starts-with? (char=? (car s-list-temp) #\^)]
           [s-list (if starts-with? (cdr s-list-temp) s-list-temp)]
           [t-list (string->list t)])
      (cond [(and starts-with? (not (char=? (car s-list) (car t-list)))) #f]
            [(not (for-all (lambda (x) (member x t-list)) s-list)) #f]  
            [else (loop s-list (member (car s-list) t-list))])))

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


