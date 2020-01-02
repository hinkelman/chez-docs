(library (chez-docs docs)
  (export doc)

  (import (chezscheme)
          (chez-docs data))

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

  (define (display-launch proc-data-selected launch?)
    (when proc-data-selected
      (display (replace-tilde (string-append (caadr proc-data-selected) "\n")))
      (when launch?
        (system (string-append "open " (cadadr proc-data-selected))))))

  (define (data-lookup proc source)
    (cond [(or (string=? source "CSUG") (string=? source "TSPL"))
           (list (dl-helper proc source))]
          [(string=? source "both")
           (let ([csug (dl-helper proc "CSUG")]
                 [tspl (dl-helper proc "TSPL")])
             (if (or csug tspl)
                 (list csug tspl)
                 (assertion-violation "(doc proc)" "procedure not found")))]
          [else
           (assertion-violation "(doc proc source)" "source not one of CSUG, TSPL, both")]))

  ;; proc-data imported with (chez-docs data)
  (define (dl-helper proc source)
    (assoc proc (cadr (assoc source proc-data)))) 

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
  )

  
