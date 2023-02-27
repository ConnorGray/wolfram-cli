# Development

## Quick Command Reference

#### Build and install the WolframCLI paclet

```shell
$ ./scripts/install-paclet.wls
```

#### Build and install the `$ wolfram` command-line tool

```shell
$ cargo install --path .
```

#### Run the WolframCLI library tests

```shell
$ wolfram-cli paclet test ./build/ConnorGray__WolframCLI ./Tests
```

#### Debug TerminalForm output

```
$ wolfram print-terminal-form-debug
```