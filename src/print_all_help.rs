//! Generate the contents of `docs/CommandLineHelp.md`
//!
//! See `docs/Maintenance.md` for more info.

use std::fmt::Write;

use clap::{Command, CommandFactory};

use crate::Cli;


pub fn print_all_help(markdown: bool) {
	if markdown {
		print_all_help_markdown();
		return;
	}

	let (main_help, subcommand_helps) = app_help();

	println!("{}", main_help);

	for (_name, message) in subcommand_helps {
		println!("{}", message);
	}
}

//======================================
// Markdown
//======================================

fn print_all_help_markdown() {
	let mut buffer = String::with_capacity(100);

	//----------------------------------
	// Write the table of contents
	//----------------------------------

	writeln!(buffer, r#"<div style="background: light-gray"><ul>"#).unwrap();
	build_table_of_contents_html(&mut buffer, Vec::new(), &Cli::command(), 0).unwrap();
	writeln!(buffer, "</ul></div>").unwrap();

	write!(buffer, "\n").unwrap();

	//----------------------------------------
	// Write the commands/subcommands sections
	//----------------------------------------

	build_command_markdown(&mut buffer, Vec::new(), &Cli::command(), 0).unwrap();

	println!("{}", buffer);
}

fn build_table_of_contents_html(
	buffer: &mut String,
	// Parent commands of `command`.
	parent_command_path: Vec<String>,
	command: &Command,
	depth: usize,
) -> std::fmt::Result {
	// Don't document commands marked with `clap(hide = true)` (which includes
	// `print-all-help`).
	if command.is_hide_set() {
		return Ok(());
	}

	// Append the name of `command` to `command_path`.
	let command_path = {
		let mut command_path = parent_command_path;
		command_path.push(command.get_name().to_owned());
		command_path
	};

	writeln!(
		buffer,
		"<li><a href=\"#{}\"><code>{}</code>↴</a></li>",
		command_path.join("-"),
		command_path.join(" ")
	)?;

	//----------------------------------
	// Recurse to write subcommands
	//----------------------------------

	for subcommand in command.get_subcommands() {
		build_table_of_contents_html(buffer, command_path.clone(), subcommand, depth + 1)?;
	}

	Ok(())
}

fn build_command_markdown(
	buffer: &mut String,
	// Parent commands of `command`.
	parent_command_path: Vec<String>,
	command: &Command,
	depth: usize,
) -> std::fmt::Result {
	// Don't document commands marked with `clap(hide = true)` (which includes
	// `print-all-help`).
	if command.is_hide_set() {
		return Ok(());
	}

	// Append the name of `command` to `command_path`.
	let command_path = {
		let mut command_path = parent_command_path.clone();
		command_path.push(command.get_name().to_owned());
		command_path
	};

	if depth >= 6 {
		panic!(
			"command path nesting depth is deeper than maximum markdown header depth: `{}`",
			command_path.join(" ")
		)
	}


	// Write the markdown heading
	writeln!(
		buffer,
		"{} `{}`\n",
		"#".repeat(depth + 1),
		command_path.join(" "),
	)?;

	if let Some(long_about) = command.get_long_about() {
		writeln!(buffer, "{}\n", long_about)?;
	} else if let Some(about) = command.get_about() {
		writeln!(buffer, "{}\n", about)?;
	}

	assert!(command.get_before_help().is_none());
	assert!(command.get_after_help().is_none());

	writeln!(
		buffer,
		"**Usage:** `{}{}`\n",
		if parent_command_path.is_empty() {
			String::new()
		} else {
			let mut s = parent_command_path.join(" ");
			s.push_str(" ");
			s
		},
		command
			.clone()
			.render_usage()
			.to_string()
			.replace("Usage: ", "")
	)?;

	//----------------------------------
	// Subcommands
	//----------------------------------

	if command.get_subcommands().next().is_some() {
		writeln!(buffer, "###### **Commands:**\n")?;

		for subcommand in command.get_subcommands() {
			if subcommand.is_hide_set() {
				continue;
			}

			writeln!(
				buffer,
				"* `{}` — {}",
				subcommand.get_name(),
				match subcommand.get_about() {
					Some(about) => about.to_string(),
					None => String::new(),
				}
			)?;
		}

		write!(buffer, "\n")?;
	}

	//----------------------------------
	// Arguments
	//----------------------------------

	if command.get_positionals().next().is_some() {
		writeln!(buffer, "###### **Arguments:**\n")?;

		for pos_arg in command.get_positionals() {
			debug_assert!(pos_arg.get_short().is_none() && pos_arg.get_long().is_none());

			write!(
				buffer,
				"* `<{}>`",
				pos_arg.get_id().to_string().to_ascii_uppercase()
			)?;

			if let Some(help) = pos_arg.get_help() {
				writeln!(buffer, " — {help}")?;
			} else {
				writeln!(buffer)?;
			}
		}

		write!(buffer, "\n")?;
	}

	//----------------------------------
	// Options
	//----------------------------------

	let non_pos: Vec<_> = command
		.get_arguments()
		.filter(|arg| !arg.is_positional())
		.collect();

	if !non_pos.is_empty() {
		writeln!(buffer, "###### **Options:**\n")?;

		for arg in non_pos {
			// Markdown list item
			write!(buffer, "* ")?;

			match (arg.get_short(), arg.get_long()) {
				(Some(short), Some(long)) => write!(buffer, "`-{}`, `--{}`", short, long)?,
				(Some(short), None) => write!(buffer, "`-{}`", short)?,
				(None, Some(long)) => write!(buffer, "`--{}`", long)?,
				(None, None) => {
					unreachable!("non-positional Arg with neither short nor long name: {arg:?}")
				},
			}

			if let Some(help) = arg.get_help() {
				writeln!(buffer, " — {}", help)?;
			}
		}

		write!(buffer, "\n")?;
	}

	//----------------------------------
	// Recurse to write subcommands
	//----------------------------------

	// Include extra space between commands. This is purely for the benefit of
	// anyone reading the source .md file.
	write!(buffer, "\n\n")?;

	for subcommand in command.get_subcommands() {
		build_command_markdown(buffer, command_path.clone(), subcommand, depth + 1)?;
	}

	Ok(())
}

//======================================
// Utilities
//======================================

fn app_help() -> (String, Vec<(String, String)>) {
	let cli_app: clap::Command = Cli::command();

	let mut subcommand_helps = Vec::new();
	for subcommand in cli_app.get_subcommands().cloned() {
		let name = subcommand.get_name();
		if name == "print-all-help" || name == "wolfram-cli" {
			continue;
		}

		subcommand_helps.push((
			name.to_owned(),
			help_message(cli_app.clone(), &["wolfram-cli", name, "--help"]),
		));
	}

	let main_help = help_message(cli_app.clone(), &["wolfram-cli", "--help"]);

	(main_help, subcommand_helps)
}

fn help_message(app: clap::Command, args: &[&str]) -> String {
	let help = app
		.try_get_matches_from(args)
		.expect_err("expect help text error");

	format!("{}", help)
}