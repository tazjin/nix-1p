Nix - A One Pager
=================

[Nix](https://nixos.org/nix/), the package manager, is built on and with Nix,
the language. This page serves as a fast intro to most of the (small) language.

Unless otherwise specified, the word "Nix" refers only to the language below.

Please file an issue if something in here confuses you or you think something
important is missing.

<!-- markdown-toc start - Don't edit this section. Run M-x markdown-toc-refresh-toc -->
**Table of Contents**

- [Overview](#overview)
- [Language constructs](#language-constructs)
    - [Primitives / literals](#primitives--literals)
    - [Variable bindings](#variable-bindings)
    - [Functions](#functions)
        - [Multiple arguments (currying)](#multiple-arguments-currying)
        - [Multiple arguments (attribute sets)](#multiple-arguments-attribute-sets)
    - [`if ... then ... else ...`](#if--then--else-)
    - [`inherit` keyword](#inherit-keyword)
    - [`with` statements](#with-statements)
    - [`import` / `NIX_PATH` / `<entry>`](#import--nixpath--entry)
- [Standard libraries](#standard-libraries)
    - [`builtins`](#builtins)
    - [`pkgs.lib`](#pkgslib)
    - [`pkgs` itself](#pkgs-itself)
- [Derivations](#derivations)
- [Nix Idioms](#nix-idioms)

<!-- markdown-toc end -->


# Overview

Nix is:

*   **purely functional**. It has no concept of sequential steps being executed,
    any dependency between operations is established by depending on *data* from
    previous operations.

    Everything in Nix is an expression, meaning that every directive returns
    some kind of data.

    Evaluating a Nix expression *yields a single data structure*, it does not
    execute a sequence of operations.

    Every Nix file evaluates to a *single expression*.
*   **lazy**. It will only evaluate expressions when their result is actually
    requested.

    For example, the builtin function `throw` causes evaluation to stop.
    Entering the following expression works fine however, because we never
    actually ask for the part of the structure that causes the `throw`.

    ```nix
    let attrs = { a = 15; b = builtins.throw "Oh no!"; };
    in "The value of 'a' is ${toString attrs.a}"
    ```
*   **purpose-built**. Nix only exists to be the language for Nix, the package
    manager. While people have occasionally used it for other use-cases, it is
    explicitly not a general-purpose language.

# Language constructs

This section describes the language constructs in Nix. It is a small language
and most of these should be self-explanatory.

## Primitives / literals

Nix has a handful of data types which can be represented literally in source
code, similar to many other languages.

```nix
# numbers
42
1.72394

# strings & paths
"hello"
./some-file.json

# strings support interpolation
"Hello ${name}"

# multi-line strings (common prefix whitespace is dropped)
''
first line
second line
''

# lists (note: no commas!)
[ 1 2 3 ]

# attribute sets (field access with dot syntax)
{ a = 15; b = "something else"; }

# recursive attribute sets (fields can reference each other)
rec { a = 15; b = a * 2; }
```

## Variable bindings

Bindings in Nix are introduced locally via `let` expressions, which make some
variables available within a given scope.

For example:

```nix
let
  a = 15;
  b = 2;
in a * b

# yields 30
```

Variables are immutable. This means that after defining what `a` or `b` are, you
can not *modify* their value in the scope in which they are available.

You can nest `let`-expressions to shadow variables.

Variables are *not* available outside of the scope of the `let` expression.
There are no global variables.

## Functions

All functions in Nix are anonymous. This means that they are treated just like
data. Giving them names is accomplished by assigning them to variables, or
setting them as values in an attribute set (more on that below).

```
# simple function
# declaration is simply the argument followed by a colon
name: "Hello ${name}"
```

### Multiple arguments (currying)

Technically any Nix function can only accept **one argument**. Sometimes
however, a function needs multiple arguments. This is achieved in Nix via
[currying][], which means to create a function with one argument, that returns a
function with another argument, that returns ... and so on.

For example:

```nix
name: age: "${name} is ${toString age} years old"
```

An additional benefit of this approach is that you can pass one parameter to a
curried function, and receive back a function that you can re-use (similar to
partial application):

```nix
let
  multiply = a: b: a * b;
  doubleIt = multiply 2; # at this point we have passed in the value for 'a' and
                         # receive back another function that still expects 'b'
in
  doubleIt 15

# yields 30
```

### Multiple arguments (attribute sets)

Another way of specifying multiple arguments to a function in Nix is to make it
accept an attribute set, which enables multiple other features:

```nix
{ name, age }: "${name} is ${toString age} years old"
```

Using this method, we gain the ability to specify default arguments (so that
callers can omit them):

```nix
{ name, age ? 42 }: "${name} is ${toString age} years old"

```

Or in practice:

```nix
let greeter =  { name, age ? 42 }: "${name} is ${toString age} years old";
in greeter { name = "Slartibartfast"; }

# yields "Slartibartfast is 42 years old"
# (note: Slartibartfast is actually /significantly/ older)
```

Additionally we can introduce an ellipsis using `...`, meaning that we can
accept an attribute set as our input that contains more variables than are
needed for the function.

```nix
let greeter = { name, age, ... }: "${name} is ${toString age} years old";
    person = {
      name = "Slartibartfast";
      age = 42;
      # the 'email' attribute is not expected by the 'greeter' function ...
      email = "slartibartfast@magrath.ea";
    };
in greeter person # ... but the call works due to the ellipsis.
```

## `if ... then ... else ...`

Nix has simple conditional support. Note that `if` is an **expression** in Nix,
which means that both branches must be specified.

```nix
if someCondition
then "it was true"
else "it was false"
```

## `inherit` keyword

The `inherit` keyword is used in attribute sets or `let` bindings to "inherit"
variables from the parent scope.

In short, a statement like `inherit foo;` expands to `foo = foo;`.

Consider this example:

```nix
let
  name = "Slartibartfast";
  # ... other variables
in {
  name = name; # set the attribute set key 'name' to the value of the 'name' var
  # ... other attributes
}
```

The `name = name;` line can be replaced with `inherit name;`:

```nix
let
  name = "Slartibartfast";
  # ... other variables
in {
  inherit name;
  # ... other attributes
}
```

This is often convenient, especially because inherit supports multiple variables
at the same time as well as "inheritance" from other attribute sets:

```nix
inherit name age; # equivalent to `name = name; age = age;`

inherit (otherAttrs) email; # equivalent to `email = otherAttrs.email`;
```

## `with` statements

The `with` statement "imports" all attributes from an attribute set into
variables of the same name:

```nix
let attrs = { a = 15; b = 2; };
in with attrs; a + b # 'a' and 'b' become variables in the scope following 'with'
```

## `import` / `NIX_PATH` / `<entry>`

Nix files can import each other by using the `import` keyword and a literal
path:

```nix
# assuming there is a file lib.nix with some useful functions
let myLib = import ./lib.nix;
in myLib.usefulFunction 42
```

Nix files often begin with a function header to pass parameters into the rest of
the file, so you will often see imports of the form `import ./some-file { ... }`.

Nix has a concept of a `NIX_PATH` (similar to the standard `PATH` environment
variable) which contains named aliases for file paths containing Nix
expressions.

In a standard Nix installation, several [channels][] will be present (for
example `nixpkgs` or `nixos-unstable`) on the `NIX_PATH`.

`NIX_PATH` entries can be accessed using the `<entry>` syntax, which simply
evaluates to their file path:

```nix
<nixpkgs>
# might yield something like `/home/tazjin/.nix-defexpr/channels/nixpkgs`
```

This is commonly used to import from channels:

```nix
let pkgs = import <nixpkgs> {};
in pkgs.something
```

# Standard libraries

Yes, libraries, plural.

Nix has three major things that could be considered its standard library and
while there's a lot of debate to be had about this point, you still need to know
all three.

## `builtins`

Nix comes with several functions that are baked into the language. These work
regardless of which other Nix code you may or may not have imported.

Most of these functions are implemented in the Nix interpreter itself, which
means that they are rather fast when compared to some of the equivalents which
are implemented in Nix itself.

The Nix manual has [a section listing all `builtins`][builtins] and their usage.

Examples of builtins that you will commonly encounter include, but are not
limited to:

* `derivation` (see [Derivations](#derivations))
* `toJSON` / `fromJSON`
* `toString`
* `toPath` / `fromPath`

The builtins also include several functions that have the (spooky) ability to
break Nix' evaluation purity. No functions written in Nix itself can do this.

Examples of those include:

* `fetchGit` which can fetch a git-repository using the environment's default
  git/ssh configuration
* `fetchTarball` which can fetch & extract archives without having to specify
  hashes

Read through the manual linked above to get the full overview.

## `pkgs.lib`

The Nix package set, commonly referred to by Nixers simply as [nixpkgs][],
contains a child attribute set called `lib` which provides a large number of
useful functions.

The canonical definition of these functions is [their source code][lib-src]. I
wrote a tool ([nixdoc][]) in 2018 which generates manual entries for these
functions, however not all of the files are included as of July 2019.

See the [Nixpkgs manual entry on `lib`][lib-manual] for the documentation.

These functions include various utilities for dealing with the data types in Nix
(lists, attribute sets, strings etc.) and it is useful to at least skim through
them to familiarise yourself with what is available.

```nix
{ pkgs ? import <nixpkgs> {} }:

with pkgs.lib; # bring contents pkgs.lib into scope

strings.toUpper "hello"

# yields "HELLO"
```

## `pkgs` itself

The Nix package set itself does not just contain packages, but also many useful
functions which you might run into while creating new Nix packages.

One particular subset of these that stands out are the [trivial builders][],
which provide utilities for writing text files or shell scripts, running shell
commands and capturing their output and so on.

```nix
{ pkgs ? import <nixpkgs> {} }:

pkgs.writeText "hello.txt" "Hello dear reader!"

# yields a derivation which creates a text file with the above content
```

# Derivations

When a Nix expression is evaluated it may yield one or more *derivations*.
Derivations describe a single build action that, when run, places one or more
outputs (whether they be files or folders) in the Nix store.

The builtin function `derivation` is responsible for creating derivations at a
lower level. Usually when Nix users create derivations they will use the
higher-level functions such as [stdenv.mkDerivation][smkd].

Please see the manual [on derivations][drv-manual] for more information, as the
general build logic is out of scope for this document.

# Nix Idioms

TODO(tazjin): This section should contain information on various Nix idioms,
such as import headers, `callPackage`, fixed points (+ overrides / overlays) and
so on.

[currying]: https://en.wikipedia.org/wiki/Currying
[builtins]: https://nixos.org/nix/manual/#ssec-builtins
[nixpkgs]: https://github.com/NixOS/nixpkgs
[lib-src]: https://github.com/NixOS/nixpkgs/tree/master/lib
[lib-manual]: https://nixos.org/nixpkgs/manual/#sec-functions-library
[channels]: https://nixos.org/nix/manual/#sec-channels
[trivial builders]: https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/trivial-builders.nix
[smkd]: https://nixos.org/nixpkgs/manual/#chap-stdenv
[drv-manual]: https://nixos.org/nix/manual/#ssec-derivation
