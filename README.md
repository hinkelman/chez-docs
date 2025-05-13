# Chez Scheme Documentation Library

Access Chez Scheme documentation from the REPL. 

Related blog posts:  
[Access Chez Scheme documentation from the REPL](https://www.travishinkelman.com/post/access-chez-scheme-documentation-from-repl/)  
[Adding string matching to chez-docs](https://www.travishinkelman.com/post/adding-string-matching-to-chez-docs/)

## Approach

`chez-docs` scrapes the web pages for the [Chez Scheme User's Guide (CSUG)](https://cisco.github.io/ChezScheme/csug9.5/) and [The Scheme Programming Language (TSPL)](https://www.scheme.com/tspl4/) and displays the extracted documentation in the REPL. `chez-docs` optionally uses a call to `system` to open documentation in your default browser. Displaying the documentation in the REPL is more convenient than opening pages in the browser, but the web pages contain formatting that make it easier to digest the documentation. The code used to scrape the Chez Scheme User's Guide for use in `chez-docs` is in a [separate repository](https://github.com/hinkelman/chez-docs-scrape). 

## Installation

### Akku

```
$ akku install chez-docs
```

For more information on getting started with [Akku](https://akkuscm.org/), see this [blog post](https://www.travishinkelman.com/posts/getting-started-with-akku-package-manager-for-scheme/). Akku uses a project-based workflow. However, `chez-docs` is unlikely to be a dependency for any project and is most useful if it is globablly installed.

### Manual

Clone or download this repository. Move `chez-docs.sls`, `summary-data.scm`, and `chez-docs-data.scm` to a directory found by `(library-directories)`. For more information on how Chez Scheme finds libraries, see blog posts for [macOS and Windows](https://www.travishinkelman.com/post/getting-started-with-chez-scheme-and-emacs/) or [Ubuntu](https://www.travishinkelman.com/post/getting-started-with-chez-scheme-and-emacs-ubuntu/).

## Import 

`(import (chez-docs))`

## Basic Usage

The main procedure is `doc` with the form `(doc proc action source)`. The `action` and `source` arguments are optional and default to `'display` and `'both`, respectively. The options for `action` are `'display`, `'open`, and `'both`. The options for `source` are `'csug`, `'tspl`, and `'both`. When `action` is `'open`, `doc` opens a link to the relevant section of either CSUG, TSPL, or both in your default browswer. `doc` makes a system call to `open` (macOS), `xdg-open` (Linux), or `start` (Windows) and requires an internet connection. Note, `proc` is shorthand for procedure, but the categories for documentation items are `procedure`, `global param`, `thread param`, `module`, and `syntax`.

```
> (doc "current-date")

CHEZ SCHEME USER'S GUIDE

procedure: (current-date)
procedure: (current-date offset)
returns: a date object representing the current date
libraries: (chezscheme)

offset represents the time-zone offset in seconds east of UTC, as described above. It must be an exact integer in the range -86400 to +86400, inclusive and defaults to the local time-zone offset. UTC may be obtained by passing an offset of zero.

If offset is not provided, then the current time zone's offset is used, and date-dst? and date-zone-name report information about the time zone. If offset is provided, then date-dst? and date-zone-name on the resulting date object produce #f.

The following examples assume the local time zone is EST.

(current-date) => #<date Thu Dec 27 23:23:20 2007>
(current-date 0) => #<date Fri Dec 28 04:23:20 2007>

(date-zone-name (current-date)) => "EST" or other system-provided string
(date-zone-name (current-date 0)) => #f


> (doc "+")

THE SCHEME PROGRAMMING LANGUAGE

procedure: (+ num ...)
returns: the sum of the arguments num ...
libraries: (rnrs base), (rnrs)  

When called with no arguments, + returns 0.  

(+) => 0
(+ 1 2) => 3
(+ 1/2 2/3) => 7/6
(+ 3 4 5) => 12
(+ 3.0 4) => 7.0
(+ 3+4i 4+3i) => 7+7i
(apply + '(1 2 3 4 5)) => 15
```

`doc` only returns results for exact matches with `proc`. To aid in discovery, `find-proc` provides exact and approximate matching of search strings. `find-proc` has one required argument, `search-string`, and two optional arguments, `search-type` and `max-results`, which default to `'exact` and `10`, respectively.

```
> (find-proc "append")
("append" "append!" "immutable-vector-append"
  "string-append" "string-append-immutable" "vector-append")

> (find-proc "append" 'fuzzy 5)
("append" "append!" "and" "apply" "cond")

> (find-proc "hashtable" 'exact 5)
Returning 5 of 48 results
("eq-hashtable-cell"
  "eq-hashtable-contains?"
  "eq-hashtable-delete!"
  "eq-hashtable-ephemeron?"
  "eq-hashtable-ref")

> (find-proc "hashtable" 'fuzzy 5)
("hashtable?"
  "hash-table?"
  "mutable"
  "eq-hashtable?"
  "hashtable-ref")
```

When `search-type` is `'exact`, the search string is compared to all possible strings and strings that match the search string are returned. When `search-type` is `'fuzzy`, the Levenshtein distance is calculated for every available string and the results are sorted in ascending order by distance. Thus, an exact match shows up at the beginning of the list.

The `^` indicates that only search strings found at the start of the procedure should be returned.

```
> (find-proc "map")
("andmap" "hash-table-map" "map" "ormap" "vector-map")
> (find-proc "^map")
("map")

> (find-proc "file" 'exact 3)
Returning 3 of 78 results
("&i/o-file-already-exists"
  "&i/o-file-does-not-exist"
  "&i/o-file-is-read-only")

> (find-proc "^file" 'exact 3)
Returning 3 of 12 results
("file-access-time" "file-buffer-size" "file-change-time")

> (find-proc "let" 'exact 5)
Returning 5 of 20 results
("delete-directory"
  "delete-file"
  "eq-hashtable-delete!"
  "fluid-let"
  "fluid-let-syntax")

> (find-proc "^let")
("let" "let*" "let*-values" "let-syntax" "let-values"
  "letrec" "letrec*" "letrec-syntax")
```

Under fuzzy matching, the `^` is included as part of the Levenshtein distance calculation and, thus, should not be included in search strings when using fuzzy matching.

```
> (find-proc "map" 'fuzzy 5)
("map" "max" "*" "+" "-")
> (find-proc "^map" 'fuzzy 5)
("map" "max" "car" "exp" "memp")
```

`chez-docs` also includes a procedure, `launch-csug-summary`, for opening the Chez Scheme User's Guide [Summary of Forms](https://cisco.github.io/ChezScheme/csug10.0/summary.html) page in your default browser. The procedure takes no arguments. 
