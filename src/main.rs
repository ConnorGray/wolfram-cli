mod config;
mod kernel;


use std::{io::Write, str::FromStr};

use clap::Parser;

use wolfram_client::{EvaluationOutcome, Packet, WolframSession};
use wolfram_expr::{Expr, Symbol};

//==========================================================
// CLI Argument Declarations
//==========================================================

/// Unofficial Wolfram command-line interface.
#[derive(Debug)]
#[derive(clap::Parser)]
#[command(name = "wolfram-cli", author, version, about)]

struct Cli {
	/// Whether to log progress and debugging information
	///
	/// Logged information includes:
	///
	/// * The Wolfram installation that is being used for evaluation.
	#[arg(short, long, action = clap::ArgAction::Count)]
	verbosity: u8,

	#[command(subcommand)]
	command: Option<Command>,
}

#[derive(Debug)]
#[derive(clap::Subcommand)]
enum Command {
	/// Subcommands for creating, modifying, and querying paclets.
	#[command(subcommand)]
	Paclet(PacletCommand),

	#[clap(hide = true)]
	PrintAllHelp {
		#[clap(long, required = true)]
		markdown: bool,
	},
}

#[derive(Debug)]
#[derive(clap::Subcommand)]
enum PacletCommand {
	/// Create a new paclet in the current directory with the specified name.
	New {
		/// Name of the paclet
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

	// Save the specified verbosity value.
	config::set_verbosity(verbosity);

	let Some(command) = command else {
		handle_wolfram();

		return;
	};

	match command {
		Command::Paclet(paclet_command) => {
			handle_paclet_command(paclet_command)
		},
		Command::PrintAllHelp { markdown } => {
			assert!(markdown);

			clap_markdown::print_help_markdown::<Cli>()
		},
	}
}

fn handle_paclet_command(command: PacletCommand) {
	match command {
		PacletCommand::New {
			shorten_to_base_name,
			name,
		} => handle_paclet_new(name, shorten_to_base_name),
	}
}

//==========================================================
// $ wolfram
//==========================================================

fn handle_wolfram() {
	let mut kernel = kernel::launch_kernel();

	let stdin = std::io::stdin();
	let mut line = String::new();

	loop {
		let Some(input_name) = process_until_ready_for_input(&mut kernel) else {
			break;
		};

		print!("\n{input_name}");
		std::io::stdout().flush().unwrap();

		// FIXME: This shouldn't just read a single line, this should read a
		//        sequence of complete input expressions.
		line.clear();
		stdin.read_line(&mut line).expect("IO error reading line");

		println!();

		kernel.enter_text(&line.trim_end_matches('\n'));
	}
}

fn process_until_ready_for_input(
	kernel: &mut WolframSession,
) -> Option<String> {
	loop {
		let Some(packet) = kernel.packets().next() else {
			return None;
		};

		match packet {
			Packet::InputName(input_name) => return Some(input_name),
			Packet::OutputName(output_name) => {
				print!("{output_name}");
				std::io::stdout().flush().unwrap();
			},
			Packet::ReturnExpression(expr) => {
				todo!("display returned expression: {expr}")
			},
			Packet::ReturnText(text) => {
				println!("{text}");
			},
			Packet::Expression(expr) => {
				todo!("display printed expression: {expr}")
			},
			Packet::Text(text) => {
				print!("{text}");
				std::io::stdout().flush().unwrap();
			},
			Packet::Message(_symbol, _name) => {
				let content_packet = match kernel.packets().next() {
					Some(packet) => packet,
					None => todo!(),
				};

				match content_packet {
					Packet::Expression(expr) => todo!("display message expression: {expr}"),
					Packet::Text(text) => {
						println!("{text}");
					},
					_ => panic!("expected message content packet, got: {content_packet:?}"),
				}
			},
			// The Kernel will have already sent a packet containing a syntax
			// message; this packet only additionally provides a position for
			// the syntax error. (Which is currently unused.)
			Packet::Syntax(_) => (),
			Packet::Return(_) => todo!(),
			Packet::Evaluate(_) => {
				panic!("client cannot perform evaluation requested by Kernel: {packet:?}")
			},
			Packet::EnterExpression(_) | Packet::EnterText(_) => {
				panic!("unexpected Kernel packet: {packet:?}")
			},
		}
	}
}

//==========================================================
// $ wolfram paclet ...
//==========================================================

//======================================
// $ wolfram paclet new
//======================================

fn handle_paclet_new(name: String, shorten_to_base_name: bool) {
	let paclet_parent_dir = std::env::current_dir()
		.expect("unable to get current working directory");

	// if verbosity > 0 {
	// 	eprintln!(
	// 		"creating paclet with name: {name} at {}",
	// 		paclet_root.display()
	// 	)
	// }

	//------------------------------------------------------
	// Launch the WolframKernel to evaluate CreatePaclet[..]
	//------------------------------------------------------

	let mut kernel = kernel::launch_kernel();

	match kernel.packets().next() {
		Some(Packet::InputName(_)) => (),
		other => panic!("unexpected WolframKernel first packet: {other:?}"),
	};

	// Evaluate:
	//
	//     Needs["PacletTools`"]
	kernel
		.enter_and_wait(Expr::normal(
			Symbol::new("System`Needs"),
			vec![Expr::string("PacletTools`")],
		))
		.outcome
		.unwrap_null();

	// Evaluate:
	//
	//     CreatePaclet[name, paclet_root]
	kernel
		.enter_and_wait(Expr::normal(
			Symbol::new("PacletTools`CreatePaclet"),
			vec![
				Expr::string(&name),
				Expr::string(
					paclet_parent_dir
						.to_str()
						.expect("paclet parent directory is not valid UTF-8"),
				),
			],
		))
		.outcome
		.unwrap_returned();

	// Evaluate:
	//
	//     Exit[]
	//
	// Wait for the kernel to execute the commands we sent and shutdown
	// gracefully.
	let outcome = kernel
		.enter_and_wait(Expr::normal(Symbol::new("System`Exit"), vec![]))
		.outcome;

	if outcome != EvaluationOutcome::KernelQuit {
		panic!("WolframKernel did not shutdown as expected: {outcome:?}");
	}

	// TODO(cleanup): Change CreatePaclet to support an option for creating the
	//                new paclet with the base name directly, so we don't have
	//                to do this rename after it has been created.
	if let PacletName::Resource { publisher, base } =
		PacletName::from_str(&name).expect("malformed paclet name")
	{
		if shorten_to_base_name {
			// Use a double underscore instead of a '/' in the paclet root
			// directory name.
			let current = format!("{publisher}__{base}");
			let desired = base;

			std::fs::rename(
				paclet_parent_dir.join(&current),
				paclet_parent_dir.join(&desired),
			)
			.expect("error shortening paclet name")
		}
	};
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

//==========================================================
// Helpers
//==========================================================
