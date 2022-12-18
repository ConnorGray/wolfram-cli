# Maintenance

This document describes steps required to maintain the
[`wolfram-cli`](../README.md) project.

### `wolfram-cli` command-line executable help text

This maintenance task should be run every time the `wolfram-cli` command-line
interface changes.

[`CommandLineHelp.md`](./CommandLineHelp.md) contains the `--help` text for the
`wolfram-cli` command-line tool. Storing this overview of the help text in a
markdown file makes the functionality of `wolfram-cli` more discoverable, and
serves as an informal "cheet sheet" of reference material. Creation of the contents
of `CommandLineHelp.md` is partially automated by the undocumented `print-all-help`
subcommand.

To update [`CommandLineHelp.md`](./CommandLineHelp.md), execute the following
command:

```
$ cargo run -- print-all-help --markdown > docs/CommandLineHelp.md
```

If the content has changed, commit it with a commit message like:
`chore: Regenerate CommandLineHelp.md`.