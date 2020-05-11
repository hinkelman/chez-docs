# Chez Scheme Documentation Library

Access Chez Scheme documentation from the REPL. 

Related blog posts:  
[Access Chez Scheme documentation from the REPL](https://www.travishinkelman.com/post/access-chez-scheme-documentation-from-repl/)  
[Adding string matching to chez-docs](https://www.travishinkelman.com/post/adding-string-matching-to-chez-docs/)

### Approach

`chez-docs` uses a call to `system` to open documentation in your default browser. The R code used to scrape the Chez Scheme User's Guide for use in chez-docs is in a [separate repository](https://github.com/hinkelman/chez-docs-scrape). 

### Installation

Download or clone this repository. Move `chez-docs.ss` and `chez-docs-data.scm` to a directory found by `(library-directories)`. `chez-docs` is unlikely to be a dependency for any project and is most useful if it is globablly installed. For more information on how Chez Scheme finds libraries, see blog posts for [macOS and Windows](https://www.travishinkelman.com/post/getting-started-with-chez-scheme-and-emacs/) or [Ubuntu](https://www.travishinkelman.com/post/getting-started-with-chez-scheme-and-emacs-ubuntu/).

### Import 

`(import (chez-docs))`

### Basic Usage

The main procedure is `doc` with the form `(doc proc action source)`. The `action` and  `source` arguments are optional and default to `'open-link` and `'both`, respectively. The options for `source` are `'csug`, `'tspl`, and `'both` where CSUG and TSPL are acronyms for the [Chez Scheme User's Guide](https://cisco.github.io/ChezScheme/csug9.5/) and [The Scheme Programming Language](https://www.scheme.com/tspl4/), respectively. When `action` is `'open-link`, `doc` opens a link to the relevant section of either CSUG, TSPL, or both in your default browswer. `doc` makes a system call to `open` (macOS), `xdg-open` (Linux), or `start` (Windows) and requires an internet connection. When `action` is `'display-form`, `doc` simply displays the form(s) for the specified `proc`. Note, `proc` is shorthand for procedure, but not all of the items in `chez-docs` are procedures, e.g., `&assertion`.

```
> (doc "append" 'display-form)
(append)
(append list ... obj)
```

`doc` only returns results for exact matches with `proc`. To aid in discovery, `find-proc` provides exact and approximate matching of search strings. `find-proc` has one required argument, `search-string`, and two optional arguments, `search-type` and `max-results`, which default to `'exact` and `10`, respectively.

```
> (find-proc "append")
("append" "append!" "string-append")
> (find-proc "append" 'fuzzy 5)
("append" "append!" "and" "apply" "cond")
> (find-proc "hashtable" 'exact 5)
("eq-hashtable-cell" "eq-hashtable-contains?" "eq-hashtable-delete!" "eq-hashtable-ephemeron?" "eq-hashtable-ref")
> (find-proc "hashtable" 'fuzzy 5)
("hashtable?" "hash-table?" "mutable" "eq-hashtable?" "hashtable-ref")
```

When `search-type` is `'exact`, the search string is compared to all possible strings and strings that match the search string are returned. When `search-type` is `'fuzzy`, the Levenshtein distance is calculated for every available string and the results are sorted in ascending order by distance. Thus, an exact match shows up at the beginning of the list.

The `^` indicates that only search strings found at the start of the procedure should be returned.

```
> (find-proc "map")
("andmap" "hash-table-map" "map" "ormap" "vector-map")
> (find-proc "^map")
("map")

> (find-proc "file" 'exact 3)
("&i/o-file-already-exists" "&i/o-file-does-not-exist" "&i/o-file-is-read-only")
> (find-proc "^file" 'exact 3)
("file-access-time" "file-buffer-size" "file-change-time")

> (find-proc "let" 'exact 5)
("delete-directory" "delete-file" "eq-hashtable-delete!" "fluid-let" "fluid-let-syntax")
> (find-proc "^let")
("let*" "let*-values" "let-syntax" "let-values" "letrec" "letrec*" "letrec-syntax")
```

Under fuzzy matching, the `^` is included as part of the Levenshtein distance calculation and, thus, should not be included in search strings when using fuzzy matching.

```
> (find-proc "map" 'fuzzy 5)
("map" "max" "*" "+" "-")
> (find-proc "^map" 'fuzzy 5)
("map" "max" "car" "exp" "memp")
```

`chez-docs` also includes a procedure, `launch-csug-summary`, for opening the Chez Scheme User's Guide [Summary of Forms](https://cisco.github.io/ChezScheme/csug9.5/summary.html) page in your default browser. The procedure takes no arguments. 

