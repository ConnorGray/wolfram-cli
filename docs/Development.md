# Development

## Quick Command Reference

#### Build and install the WolframCLI paclet

```shell
$ ./scripts/install-paclet.wls
```

#### Build and install the `$ wolfram` command-line tool

```shell
$ cargo install --path ./crates/wolfram-cli
```

#### Run the WolframCLI library tests

```shell
$ wolfram-cli paclet test ./build/ConnorGray__WolframCLI ./Tests
```

#### Debug TerminalForm output

```
$ wolfram-cli print-terminal-form-debug
```

#### Regenerate docs/CommandLineHelp.md

```
$ cargo run -- print-all-help --markdown > docs/CommandLineHelp.md
```