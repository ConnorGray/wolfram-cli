# `wolfram-cli`

#### [CLI Documentation](./docs/CommandLineHelp.md) | [*Changelog*](./docs/CHANGELOG.md) | [Contributing](#contributing)

## About

An unofficial Wolfram command-line interface.

## Usage

See [**Command Line Help**](./docs/CommandLineHelp.md).

## Installing `wolfram-cli`

This project is a development prototype, and must be build from source manually.

To install the `wolfram-cli` command-line tool, first clone this repository:

```shell
$ git clone https://github.com/ConnorGray/wolfram-cli
```

Next, install the `ConnorGray/WolframCLI` paclet locally by executing:

```shell
$ ./wolfram-cli/scripts/install-paclet.wls
```

Finally, install the `wolfram-cli` executable by invoking
[`cargo`](https://doc.rust-lang.org/cargo/):

```shell
$ cargo install --path ./wolfram-cli
```

Verify the installation by executing:

```shell
$ wolfram-cli
```

Which should open an interactive REPL interface.


## Features

#### Run paclet tests from the command-line

![`wolfram-paclet-test` output](./docs/media/wolfram-paclet-test-output.gif)

*See also: [`$ wolfram-cli paclet test`](./docs/CommandLineHelp.md#wolfram-cli-paclet-test)*

#### Add custom subcommands via "WolframCLI" paclet extensions

Given an installed paclet that declares the following extension:

```wolfram
PacletObject[<|
    ...,
    "Extensions" -> {
        ...,
        {"WolframCLI",
            "Subcommand" -> "travel-directions",
            "HandlerFunction" -> "MyPackage`HandleTravelDirectionsSubcommand"
        }
    }
|>]
```

then `$ wolfram-cli travel-directions` will be handled by the
`HandleTravelDirectionsSubcommand[..]` function:

![`wolfram-cli travel-directions` output](./docs/media/wolfram-travel-directions-output.gif)

See [examples/TravelDirectionsCLI](./examples/TravelDirectionsCLI/) for the
complete example.


## Contributing

See [**Development.md**](./docs/Development.md) for instructions on how to perform
common development tasks.

*See [Maintenance.md](./docs/Maintenance.md) for instructions on how to maintain
this project.*