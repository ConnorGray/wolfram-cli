# Command-Line Help for `wolfram-cli`

This document contains the help content for the `wolfram-cli` command-line program.

**Command Overview:**

* [`wolfram-cli`↴](#wolfram-cli)
* [`wolfram-cli paclet`↴](#wolfram-cli-paclet)
* [`wolfram-cli paclet new`↴](#wolfram-cli-paclet-new)
* [`wolfram-cli paclet build`↴](#wolfram-cli-paclet-build)
* [`wolfram-cli paclet doc`↴](#wolfram-cli-paclet-doc)
* [`wolfram-cli paclet install`↴](#wolfram-cli-paclet-install)
* [`wolfram-cli paclet test`↴](#wolfram-cli-paclet-test)

## `wolfram-cli`

Unofficial Wolfram command-line interface

**Usage:** `wolfram-cli [OPTIONS] [COMMAND]`

###### **Subcommands:**

* `paclet` — Subcommands for creating, modifying, and querying paclets

###### **Options:**

* `-v`, `--verbosity` — Whether to log progress and debugging information



## `wolfram-cli paclet`

Subcommands for creating, modifying, and querying paclets

**Usage:** `wolfram-cli paclet <COMMAND>`

###### **Subcommands:**

* `new` — Create a new paclet in the current directory with the specified name
* `build` — Build the specified paclet
* `doc` — Build paclet documentation
* `install` — Install the specified `.paclet` file
* `test` — Run tests defined for a paclet



## `wolfram-cli paclet new`

Create a new paclet in the current directory with the specified name

**Usage:** `wolfram-cli paclet new [OPTIONS] <NAME>`

###### **Arguments:**

* `<NAME>` — Name of the paclet

###### **Options:**

* `-b`, `--base` — use paclet base name as directory name



## `wolfram-cli paclet build`

Build the specified paclet

This uses [`PacletBuild[..]`](https://reference.wolfram.com/language/PacletTools/ref/PacletBuild) to build the specified paclet.

**Usage:** `wolfram-cli paclet build [OPTIONS] [PACLET_DIR] [BUILD_DIR]`

###### **Arguments:**

* `<PACLET_DIR>`
* `<BUILD_DIR>`

###### **Options:**

* `-i`, `--install` — Install the built paclet



## `wolfram-cli paclet doc`

Build paclet documentation

**Usage:** `wolfram-cli paclet doc [OPTIONS] [PACLET_DIR] [BUILD_DIR]`

###### **Arguments:**

* `<PACLET_DIR>`
* `<BUILD_DIR>`

###### **Options:**

* `--html` — Build paclet documentation into HTML
* `--open` — Automatically open the built HTML documentation



## `wolfram-cli paclet install`

Install the specified `.paclet` file

This uses [`PacletInstall`] to install the specified paclet archive file.

[`PacletInstall`]: https://reference.wolfram.com/language/ref/PacletInstall

### CLI Examples

Install a `.paclet` file:

```shell $ wolfram-cli paclet install MyPaclet.paclet ```

**Usage:** `wolfram-cli paclet install <PACLET_FILE>`

###### **Arguments:**

* `<PACLET_FILE>`



## `wolfram-cli paclet test`

Run tests defined for a paclet

This uses `` PacletTools`PacletTest `` to execute any tests defined by the specified paclet.

**Usage:** `wolfram-cli paclet test [OPTIONS] [PACLET_DIR] [TESTS_PATH]`

###### **Arguments:**

* `<PACLET_DIR>` — Optional path to a paclet directory
* `<TESTS_PATH>` — Optional file or directory containing tests to be run

###### **Options:**

* `-C`, `--diff-context <DIFF_CONTEXT>` — Lines of context to print before and after a diff in test output



<hr/>

<small><i>
    This document was generated automatically by
    <a href="https://crates.io/crates/clap-markdown"><code>clap-markdown</code></a>.
</i></small>

