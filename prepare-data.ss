(import (chez-stats chez-stats))

(define csug (cdr (read-tsv "R/CSUG.tsv")))
(define tspl (cdr (read-tsv "R/TSPL.tsv")))

(define csug-alist (map (lambda (x) (list (car x) (cdr x))) csug))
(define tspl-alist (map (lambda (x) (list (car x) (cdr x))) tspl))

(define data (list (list "CSUG" csug-alist)
                   (list "TSPL" tspl-alist)))

(with-output-to-file "data.scm" (lambda () (write data)))


