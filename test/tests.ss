(import (chez-docs docs)
	(srfi s64 testing))


(test-begin "fuzzy-test")
(test-equal '("append" "append!" "and" "apply" "cond") (find-proc "append" 5 #t))
(test-equal '("hashtable?" "hash-table?" "mutable") (find-proc "hashtable" 3 #t))
(test-equal '("hash-table?" "hashtable?" "eq-hashtable?") (find-proc "hash-table?" 3 #t))
(test-equal '("read" "and" "cadr" "car" "cd") (find-proc "head" 5 #t))
(test-equal '("map" "max" "*" "+" "-") (find-proc "map" 5 #t))
(test-end "fuzzy-test")

(test-begin "partial-match-test")
(test-equal '("hash-table?") (find-proc "hash-table?" 3))
(test-equal '("list-head" "lookahead-char" "lookahead-u8" "make-boot-header") (find-proc "head" 5))
(test-equal '("append" "append!" "string-append") (find-proc "append"))
(test-equal '("andmap" "hash-table-map" "map" "ormap" "vector-map") (find-proc "map"))
(test-end "partial-match-test")

(test-begin "starts-with-test")
(test-equal '("map") (find-proc "^map"))
(test-equal '("hash-table-for-each" "hash-table-map" "hash-table?" "hashtable-cell") (find-proc "^hash" 4))
(test-equal '("fl*" "fl+" "fl-") (find-proc "^fl" 3))
(test-end "starts-with-test")

(exit (if (zero? (test-runner-fail-count (test-runner-get))) 0 1))


