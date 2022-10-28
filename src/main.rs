use std::str::FromStr;

use clap::Parser;

//==========================================================
// CLI Argument Declarations
//==========================================================

#[derive(Debug)]
#[derive(clap::Parser)]
#[command(name = "wolfram-cli", author, version, about)]

struct Cli {
	#[arg(short, long, action = clap::ArgAction::Count)]
	verbosity: u8,

	#[command(subcommand)]
	command: Command,
}

#[derive(Debug)]
#[derive(clap::Subcommand)]
enum Command {
	#[command(subcommand)]
	Paclet(PacletCommand),
}

#[derive(Debug)]
#[derive(clap::Subcommand)]
enum PacletCommand {
	New {
		name: String,
		#[arg(
			long = "base",
			short = 'b',
			help = "use paclet base name as directory name"
		)]
		shorten_to_base_name: bool,
	},
}

//==========================================================
// main()
//==========================================================

fn main() {
	let args = Cli::parse();

	// dbg!(&args);

	let Cli { verbosity, command } = args;

	match command {
		Command::Paclet(paclet_command) => handle_paclet_command(paclet_command, verbosity),
	}
}

fn handle_paclet_command(command: PacletCommand, verbosity: u8) {
	match command {
		PacletCommand::New {
			shorten_to_base_name,
			name,
		} => handle_paclet_new(name, shorten_to_base_name, verbosity),
	}
}

//==========================================================
// $ wolfram paclet ...
//==========================================================

fn handle_paclet_new(name: String, shorten_to_base_name: bool, verbosity: u8) {
	let filename = match PacletName::from_str(&name).expect("malformed paclet name") {
		PacletName::Normal(name) => name,
		PacletName::Resource { publisher, base } => {
			if shorten_to_base_name {
				base
			} else {
				// Use a double underscore instead of a '/' in the paclet root
				// directory name.
				format!("{publisher}__{base}")
			}
		},
	};

	let paclet_root = std::env::current_dir()
		.expect("unable to get current working directory")
		.join(filename);

	if verbosity > 0 {
		eprintln!(
			"creating paclet with name: {name} at {}",
			paclet_root.display()
		)
	}
}

enum PacletName {
	Resource { publisher: String, base: String },
	Normal(String),
}

impl FromStr for PacletName {
	type Err = String;

	fn from_str(name: &str) -> Result<Self, Self::Err> {
		let components: Vec<&str> = name.split('/').collect();

		match *components {
			[_] => Ok(PacletName::Normal(name.to_owned())),
			[publisher, base] => Ok(PacletName::Resource {
				publisher: publisher.to_owned(),
				base: base.to_owned(),
			}),
			[..] => Err(format!(
				"paclet names can contain at most one forward slash ('/') character: {:?}",
				name
			)),
		}
	}
}
