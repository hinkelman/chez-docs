# Chez Scheme Documentation Library

Access Chez Scheme documentation from the REPL. 

Related blog posts:  
[Access Chez Scheme documentation from the REPL](https://www.travishinkelman.com/post/access-chez-scheme-documentation-from-repl/)  
[Adding string matching to chez-docs](https://www.travishinkelman.com/post/adding-string-matching-to-chez-docs/)

### Installation

```
$ cd ~/scheme # where '~/scheme' is the path to your Chez Scheme libraries
$ git clone git://github.com/hinkelman/chez-docs.git
```

For more information on installing Chez Scheme libraries, see blog posts for [macOS and Windows](https://www.travishinkelman.com/post/getting-started-with-chez-scheme-and-emacs/) or [Ubuntu](https://www.travishinkelman.com/post/getting-started-with-chez-scheme-and-emacs-ubuntu/).

### Import 

Import `chez-docs` procedure: `(import (chez-docs docs))`

### Basic Usage

The main procedure is `doc` with the form `(doc proc source launch?)`. The `source` and `launch?` arguments are optional and default to `"both"` and `#t`, respectively. The options for `source` are `"CSUG"`, `"TSPL"`, and `"both"` where CSUG and TSPL are acronyms for the [Chez Scheme User's Guide](https://cisco.github.io/ChezScheme/csug9.5/) and [The Scheme Programming Language](https://www.scheme.com/tspl4/), respectively. When `launch?` is `#t`, `doc` opens a link to the relevant section of either CSUG, TSPL, or both in your default browswer. `doc` makes a system call to `open` (macOS) or `xdg-open` (Linux) and requires an internet connection. When `launch?` is `#f`, `doc` simply displays the form(s) for the specified `proc`. Note, `proc` is shorthand for procedure, but not all of the items in `chez-docs` are procedures, e.g., `&assertion`.

```
> (doc "append" "both" #f)
(append)
(append list ... obj)
```

`doc` only returns results for exact matches with `proc`. To aid in discovery, `find-proc` provides exact and approximate matching of search strings. `find-proc` has one required argument, `search-string`, and two optional arguments, `max-results` and `fuzzy?`, which default to `10` and `#f`. 

```
> (find-proc "append")
("append" "append!" "string-append")
> (find-proc "append" 5 #t)
("append" "append!" "and" "apply" "cond")
> (find-proc "hashtable" 5)
("eq-hashtable-cell" "eq-hashtable-contains?" "eq-hashtable-delete!" "eq-hashtable-ephemeron?" "eq-hashtable-ref")
> (find-proc "hashtable" 5 #t)
("hashtable?" "hash-table?" "mutable" "eq-hashtable?" "hashtable-ref")
```

When `fuzzy?` is false, the search string is compared to all possible strings and strings that match the search string are returned. When `fuzzy?` is true, the Levenshtein distance is calculated for every available string and the results are sorted in ascending order by distance. Thus, an exact match shows up at the beginning of the list.

The `^` indicates that only search strings found at the start of the procedure should be returned.

```
> (find-proc "map")
("andmap" "hash-table-map" "map" "ormap" "vector-map")
> (find-proc "^map")
("map")

> (find-proc "file" 3)
("&i/o-file-already-exists" "&i/o-file-does-not-exist" "&i/o-file-is-read-only")
> (find-proc "^file" 3)
("file-access-time" "file-buffer-size" "file-change-time")

> (find-proc "let" 5)
("delete-directory" "delete-file" "let*" "let*-values" "let-syntax")
> (find-proc "^let")
("let*" "let*-values" "let-syntax" "let-values" "letrec" "letrec*" "letrec-syntax")
```

Under fuzzy matching, the `^` is included as part of the Levenshtein distance calculation and, thus, should not be included in search strings when using fuzzy matching.

```
> (find-proc "map" 5 #t)
("map" "max" "*" "+" "-")
> (find-proc "^map" 5 #t)
("map" "max" "car" "exp" "memp")
```

`chez-docs` also includes a procedure, `launch-csug-summary`, for opening the Chez Scheme User's Guide [Summary of Forms](https://cisco.github.io/ChezScheme/csug9.5/summary.html) page in your default browser. The procedure takes no arguments. 

