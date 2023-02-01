mod config;
mod kernel;


use std::{io::Write, path::PathBuf, str::FromStr};

use clap::Parser;
use colored::Colorize;

use wolfram_client::{EvaluationOutcome, Packet, PacketExpr, WolframSession};
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

	/// Command that prints an example of every type of object that has special
	/// formatting.
	#[clap(hide = true)]
	PrintTerminalFormDebug,
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
	/// Build the specified paclet
	///
	/// This uses [`PacletBuild[..]`](https://reference.wolfram.com/language/PacletTools/ref/PacletBuild)
	/// to build the specified paclet.
	Build {
		paclet_dir: Option<PathBuf>,
		build_dir: Option<PathBuf>,
		/// Install the built paclet.
		#[arg(short, long)]
		install: bool,
	},
	/// Build paclet documentation
	Doc {
		paclet_dir: Option<PathBuf>,
		build_dir: Option<PathBuf>,
		/// Build paclet documentation into HTML
		#[arg(long, requires = "build_dir")]
		html: bool,
		/// Automatically open the built HTML documentation
		#[arg(long, requires = "html")]
		open: bool,
	},
	/// Install the specified `.paclet` file
	///
	/// This uses [`PacletInstall`] to install the specified paclet archive file.
	///
	/// [`PacletInstall`]: https://reference.wolfram.com/language/ref/PacletInstall
	///
	/// ### CLI Examples
	///
	/// Install a `.paclet` file:
	///
	/// ```shell
	/// $ wolfram-cli paclet install MyPaclet.paclet
	/// ```
	Install { paclet_file: PathBuf },
	/// Run tests defined for a paclet
	///
	/// This uses `` PacletTools`PacletTest `` to execute any tests defined by
	/// the specified paclet.
	//
	// TODO: PacletTest is undocumented. Once it is, include a link to it above.
	Test {
		/// Optional path to a paclet directory.
		///
		/// This should be a directory containing a `PacletInfo.wl` file.
		///
		/// This no paclet directory is specified, the current directory is
		/// the default.
		paclet_dir: Option<PathBuf>,
	},
}

//==========================================================
// main()
//==========================================================

fn main() {
	let args = match Cli::try_parse() {
		Ok(args) => args,
		Err(error) => {
			// FIXME:
			//   Only defer to custom subcommand handlers if it was a top-level
			//   subcommand that doesn't exist in `Cli`.
			//
			//   E.g. `$ wolfram-cli paclet does-not-exist` should NOT be
			//   handled by a {"WolframCLI", "Subcommand" -> "paclet", ...}
			//   extension.
			//
			//   The current implementation effectively allows "WolframCLI"
			//   extensions to extend built-in subcommands, which isn't
			//   intentional; allowing that officially should be a deliberate
			//   design decision.
			return handle_custom_command(error);

			// NOTE: This code isn't quite right, because the InvalidSubcommand
			//       error is also generated for invalid sub-sub-commands (like
			//       $ wolfram-cli paclet does-not-exist).
			//
			// println!("ERROR: {:#?}", error);
			// if error.kind() == clap::error::ErrorKind::InvalidSubcommand {
			// 	return handle_custom_command(error);
			// } else {
			// 	error.exit();
			// }
		},
	};

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
		Command::PrintTerminalFormDebug => {
			handle_print_terminal_form_debug_command()
		},
	}
}

fn handle_paclet_command(command: PacletCommand) {
	match command {
		PacletCommand::New {
			shorten_to_base_name,
			name,
		} => handle_paclet_new(name, shorten_to_base_name),
		PacletCommand::Build {
			paclet_dir,
			build_dir,
			install,
		} => handle_paclet_build(paclet_dir, build_dir, install),
		PacletCommand::Doc {
			paclet_dir,
			build_dir,
			html,
			open,
		} => handle_paclet_doc(paclet_dir, build_dir, html, open),
		PacletCommand::Install { paclet_file } => {
			handle_paclet_install(paclet_file)
		},
		PacletCommand::Test { paclet_dir } => handle_paclet_test(paclet_dir),
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

		let input_name = input_name.trim_end();
		print!("\n{} ", input_name.bold());
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
				print!("{}", text.dimmed());
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
						println!("{}", text.red().underline());
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
		.enter_and_wait_with_output_handler(
			Expr::normal(
				Symbol::new("System`Needs"),
				vec![Expr::string("PacletTools`")],
			),
			&mut print_command_output,
		)
		.unwrap_null();

	// Evaluate:
	//
	//     CreatePaclet[name, paclet_root]
	kernel
		.enter_and_wait_with_output_handler(
			Expr::normal(
				Symbol::new("PacletTools`CreatePaclet"),
				vec![
					Expr::string(&name),
					Expr::string(
						paclet_parent_dir.to_str().expect(
							"paclet parent directory is not valid UTF-8",
						),
					),
				],
			),
			&mut print_command_output,
		)
		.unwrap_returned();

	// Evaluate:
	//
	//     Exit[]
	//
	// Wait for the kernel to execute the commands we sent and shutdown
	// gracefully.
	let outcome = kernel.enter_and_wait_with_output_handler(
		Expr::normal(Symbol::new("System`Exit"), vec![]),
		&mut print_command_output,
	);

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

//======================================
// $ wolfram paclet install
//======================================

fn handle_paclet_install(paclet_file: PathBuf) {
	let paclet_file = match paclet_file.canonicalize() {
		Ok(file) => file,
		// TODO: Make this error nicer, as this can commonly occur if the
		//       specified file path doesn't exist.
		Err(err) => todo!("error getting absolute paclet file path: {err}"),
	};

	let paclet_file: &str = match paclet_file.to_str() {
		Some(paclet_file) => paclet_file,
		None => panic!(".paclet file path is not valid UTF-8"),
	};

	let mut kernel = kernel::launch_kernel();

	match kernel.packets().next() {
		Some(Packet::InputName(_)) => (),
		other => panic!("unexpected WolframKernel first packet: {other:?}"),
	};

	load_wolfram_cli_paclet(&mut kernel);

	// Evaluate:
	//
	//     CommandPacletInstall[paclet_file]
	let outcome = kernel.enter_and_wait_with_output_handler(
		Expr::normal(
			Symbol::new("ConnorGray`WolframCLI`CommandPacletInstall"),
			vec![Expr::string(paclet_file)],
		),
		&mut print_command_output,
	);

	match outcome {
		EvaluationOutcome::Null => (),
		EvaluationOutcome::Returned(returned) => {
			todo!("unexpected return value: {returned:?}")
		},
		EvaluationOutcome::KernelQuit => {
			todo!("Kernel unexpectedly quit")
		},
	};
}

//======================================
// $ wolfram paclet build [PACLET_DIR] [BUILD_DIR]
//======================================

fn handle_paclet_build(
	paclet_dir: Option<PathBuf>,
	build_dir: Option<PathBuf>,
	install: bool,
) {
	let paclet_dir = unwrap_path_or_default_to_current_dir(paclet_dir);
	let paclet_dir: &str = match paclet_dir.to_str() {
		Some(paclet_dir) => paclet_dir,
		None => panic!("paclet directory path is not valid UTF-8"),
	};

	let mut kernel = kernel::launch_kernel();

	match kernel.packets().next() {
		Some(Packet::InputName(_)) => (),
		other => panic!("unexpected WolframKernel first packet: {other:?}"),
	};

	load_wolfram_cli_paclet(&mut kernel);

	let build_dir: Expr = match build_dir {
		Some(build_dir) => {
			let build_dir: &str = match build_dir.to_str() {
				Some(build_dir) => build_dir,
				None => {
					panic!("paclet build directory path is not valid UTF-8")
				},
			};
			Expr::string(build_dir)
		},
		None => Expr::symbol(Symbol::new("System`Automatic")),
	};

	// Evaluate:
	//
	//     CommandPacletBuild[paclet_dir, build_dir]
	let outcome = kernel.enter_and_wait_with_output_handler(
		Expr::normal(
			Symbol::new("ConnorGray`WolframCLI`CommandPacletBuild"),
			vec![Expr::string(paclet_dir), build_dir, Expr::from(install)],
		),
		&mut print_command_output,
	);

	match outcome {
		EvaluationOutcome::Null => (),
		EvaluationOutcome::Returned(returned) => {
			todo!("unexpected return value: {returned:?}")
		},
		EvaluationOutcome::KernelQuit => {
			todo!("Kernel unexpectedly quit")
		},
	};
}

//======================================
// $ wolfram paclet doc [PACLET_DIR] [--html] [--open]
//======================================

fn handle_paclet_doc(
	paclet_dir: Option<PathBuf>,
	build_dir: Option<PathBuf>,
	html: bool,
	open: bool,
) {
	let paclet_dir = unwrap_path_or_default_to_current_dir(paclet_dir);
	let paclet_dir: &str = match paclet_dir.to_str() {
		Some(paclet_dir) => paclet_dir,
		None => panic!("paclet directory path is not valid UTF-8"),
	};

	let build_dir: Expr = match build_dir {
		Some(build_dir) => {
			let build_dir: &str = match build_dir.to_str() {
				Some(build_dir) => build_dir,
				None => {
					panic!("paclet build directory path is not valid UTF-8")
				},
			};
			Expr::string(build_dir)
		},
		None => Expr::symbol(Symbol::new("System`Automatic")),
	};

	let mut kernel = kernel::launch_kernel();

	match kernel.packets().next() {
		Some(Packet::InputName(_)) => (),
		other => panic!("unexpected WolframKernel first packet: {other:?}"),
	};

	load_wolfram_cli_paclet(&mut kernel);

	// Evaluate:
	//
	//     CommandPacletDoc[paclet_dir, build_dir, html, open]
	let outcome = kernel.enter_and_wait_with_output_handler(
		Expr::normal(
			Symbol::new("ConnorGray`WolframCLI`CommandPacletDoc"),
			vec![
				Expr::string(paclet_dir),
				build_dir,
				Expr::from(html),
				Expr::from(open),
			],
		),
		&mut print_command_output,
	);

	match outcome {
		EvaluationOutcome::Null => (),
		EvaluationOutcome::Returned(returned) => {
			todo!("unexpected return value: {returned:?}")
		},
		EvaluationOutcome::KernelQuit => {
			todo!("Kernel unexpectedly quit")
		},
	};
}

//======================================
// $ wolfram paclet test [PACLET_DIR]
//======================================

fn handle_paclet_test(paclet_dir: Option<PathBuf>) {
	let paclet_dir = unwrap_path_or_default_to_current_dir(paclet_dir);
	let paclet_dir: &str = match paclet_dir.to_str() {
		Some(paclet_dir) => paclet_dir,
		None => panic!("paclet directory path is not valid UTF-8"),
	};

	let mut kernel = kernel::launch_kernel();

	match kernel.packets().next() {
		Some(Packet::InputName(_)) => (),
		other => panic!("unexpected WolframKernel first packet: {other:?}"),
	};

	load_wolfram_cli_paclet(&mut kernel);

	// Evaluate:
	//
	//     CommandPacletTest[paclet_dir]
	let outcome = kernel.enter_and_wait_with_output_handler(
		Expr::normal(
			Symbol::new("ConnorGray`WolframCLI`CommandPacletTest"),
			vec![Expr::string(paclet_dir)],
		),
		&mut print_command_output,
	);

	match outcome {
		EvaluationOutcome::Null => (),
		EvaluationOutcome::Returned(returned) => {
			todo!("unexpected return value: {returned:?}")
		},
		EvaluationOutcome::KernelQuit => {
			todo!("Kernel unexpectedly quit")
		},
	};
}

//==========================================================
// Handle custom commands
//==========================================================

fn handle_custom_command(error: clap::Error) {
	// TODO: This will panic if any arguments are not valid Unicode; handle that
	//       more gracefully.
	let args = std::env::args();

	let mut kernel = kernel::launch_kernel();

	match kernel.packets().next() {
		Some(Packet::InputName(_)) => (),
		other => panic!("unexpected WolframKernel first packet: {other:?}"),
	};

	load_wolfram_cli_paclet(&mut kernel);

	let args: Vec<Expr> = args
		.into_iter()
		.map(|arg: String| Expr::string(arg))
		.collect();

	// Evaluate:
	//
	//     CommandHandleCustom[args]
	let outcome = kernel.enter_and_wait_with_output_handler(
		Expr::normal(
			Symbol::new("ConnorGray`WolframCLI`CommandHandleCustom"),
			vec![Expr::list(args)],
		),
		&mut print_command_output,
	);

	match outcome {
		EvaluationOutcome::Null => (),
		EvaluationOutcome::Returned(returned) => match returned {
			PacketExpr::Text(e) if e == "\"NoCustomHandler\"" => {
				error.exit();
			},
			PacketExpr::Expr(e) if e == Expr::string("NoCustomHandler") => {
				error.exit();
			},
			_ => {
				eprintln!("unexpected expression returned from CommandHandleCustom: {returned:#?}");

				error.exit();
			},
		},
		EvaluationOutcome::KernelQuit => {
			todo!("Kernel unexpectedly quit")
		},
	};
}

//==========================================================
// $ wolfram dump-terminal-form-debug
//==========================================================

fn handle_print_terminal_form_debug_command() {
	let mut kernel = kernel::launch_kernel();

	match kernel.packets().next() {
		Some(Packet::InputName(_)) => (),
		other => panic!("unexpected WolframKernel first packet: {other:?}"),
	};

	load_wolfram_cli_paclet(&mut kernel);

	// Evaluate:
	//
	//     CommandPrintTerminalFormDebug[]
	let outcome = kernel.enter_and_wait_with_output_handler(
		Expr::normal(
			Symbol::new("ConnorGray`WolframCLI`CommandPrintTerminalFormDebug"),
			vec![],
		),
		&mut print_command_output,
	);

	outcome.unwrap_null();
}

//==========================================================
// Helpers
//==========================================================

fn load_wolfram_cli_paclet(kernel: &mut WolframSession) {
	// Evaluate:
	//
	//     Needs["ConnorGray`WolframCLI`"]
	let outcome = kernel.enter_and_wait_with_output_handler(
		r#"Needs["ConnorGray`WolframCLI`"]"#,
		&mut print_command_output,
	);

	match outcome {
		EvaluationOutcome::Null => (),
		EvaluationOutcome::Returned(returned) => {
			panic!("unexpected result loading ConnorGray`WolframCLI`: {returned:?}")
		},
		EvaluationOutcome::KernelQuit => todo!(),
	}

	// Evaluate:
	//
	//     SetOptions[$Output, PageWidth -> Infinity]
	//
	// Command output shouldn't use the default line wrapping used in
	// interactive mode.
	let _outcome = kernel.enter_and_wait_with_output_handler(
		r#"SetOptions[$Output, PageWidth -> Infinity]"#,
		&mut print_command_output,
	);
}

/// Print output generated by the Kernel during the execution of the WL code
/// that implements a `$ wolfram-cli` command.
///
/// Intended to be used with [`WolframSession::enter_and_wait_with_output_handler()`].
fn print_command_output(output: wolfram_client::Output) {
	match output {
		wolfram_client::Output::Print(packet_expr) => match packet_expr {
			PacketExpr::Expr(expr) => todo!("display printed expr: {expr}"),
			PacketExpr::Text(text) => {
				print!("{text}");
				std::io::stdout().flush().unwrap();
			},
		},
		wolfram_client::Output::Message(wolfram_client::Message {
			symbol: _,
			name: _,
			content,
		}) => match content {
			PacketExpr::Expr(expr) => todo!("display message expr: {expr}"),
			PacketExpr::Text(text) => {
				println!("{text}");
			},
		},
	}
}

fn unwrap_path_or_default_to_current_dir(path: Option<PathBuf>) -> PathBuf {
	path.unwrap_or_else(|| {
		std::env::current_dir()
			.expect("unable to get process current working directory")
	})
}
