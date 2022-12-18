# Command-Line Help for `wolfram-cli`

This document contains the help content for the `wolfram-cli` command-line program.

**Command Overview:**

* [`wolfram-cli`↴](#wolfram-cli)
* [`wolfram-cli paclet`↴](#wolfram-cli-paclet)
* [`wolfram-cli paclet new`↴](#wolfram-cli-paclet-new)

## `wolfram-cli`

Unofficial Wolfram command-line interface

**Usage:** `wolfram-cli [OPTIONS] <COMMAND>`

###### **Subcommands:**

* `paclet` — Subcommands for creating, modifying, and querying paclets

###### **Options:**

* `-v`, `--verbosity` — Whether to log progress and debugging information



## `wolfram-cli paclet`

Subcommands for creating, modifying, and querying paclets

**Usage:** `wolfram-cli paclet <COMMAND>`

###### **Subcommands:**

* `new` — Create a new paclet in the current directory with the specified name



## `wolfram-cli paclet new`

Create a new paclet in the current directory with the specified name

**Usage:** `wolfram-cli paclet new [OPTIONS] <NAME>`

###### **Arguments:**

* `<NAME>` — Name of the paclet

###### **Options:**

* `-b`, `--base` — use paclet base name as directory name



<hr/>

<small><i>
    This document was generated automatically by
    <a href="https://crates.io/crates/clap-markdown"><code>clap-markdown</code></a>.
</i></small>

