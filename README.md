# Chez Scheme Documentation Library

Access Chez Scheme documentation from the REPL. 

Related blog post:  
[Library to access Chez Scheme documentation from the REPL](https://www.travishinkelman.com/post/access-chez-scheme-documentation-from-repl/)  

### Installation

```
$ cd ~/scheme # where '~/scheme' is the path to your Chez Scheme libraries
$ git clone git://github.com/hinkelman/chez-docs.git
```

For more information on installing Chez Scheme libraries, see this [blog post](https://www.travishinkelman.com/post/getting-started-with-chez-scheme-and-emacs/).

### Import 

Import `chez-docs` procedure: `(import (chez-docs docs))`

### Basic Usage

The library contains only one procedure, `(doc proc source launch?)`. The `source` and `launch?` arguments are optional and default to `"both"` and `#t`, respectively. The options for `source` are `"CSUG"`, `"TSPL"`, and `"both"` where CSUG and TSPL are acronyms for the [Chez Scheme User's Guide](https://cisco.github.io/ChezScheme/csug9.5/) and [The Scheme Programming Language](https://www.scheme.com/tspl4/), respectively. When `launch?` is `#t`, `doc` opens a link to the relevant section of either CSUG, TSPL, or both in your default browswer. `(doc)` makes a system call to `open` and requires an internet connection. To test if `open` is available on your system, try running the following command in your shell `open https://www.travishinkelman.com`. When `launch?` is `#f`, `doc` simply displays the form(s) for the specified `proc`. Note, `proc` is shorthand for procedure, but not all of the items in `chez-docs` are procedures, e.g., `&assertion`.

```
> (doc "append" "both" #f)
(append)
(append list ... obj)
```

