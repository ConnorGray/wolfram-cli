mod from_expr;

use std::collections::BTreeMap;

use wolfram_library_link::{
	self as wll,
	expr::{Expr, Symbol},
};

use crate::from_expr::FromExpr;

//==========================================================
// Wolfram symbolic representation of clap functionality
//==========================================================

pub(crate) struct ClapCommand {
	command_name: String,
	args: Vec<ClapArg>,
	subcommands: Option<Vec<ClapCommand>>,
	settings: Option<ClapCommandSettings>,
}

pub(crate) struct ClapCommandSettings {
	arg_required_else_help: Option<bool>,
}

pub(crate) struct ClapArg {
	arg_name: String,
	action: Option<clap::ArgAction>,
	/// 3rd argument of `ClapArg[..]`:
	///
	/// * Nothing => `None`
	/// * `Automatic` => `None`
	/// * `"Long"` => `Some((FlagSetting::Automatic, FlagSetting::None))`
	/// * `"Long" -> value` => `Some((FlagSetting::Some(value), FlagSetting::None))`
	/// * `{"Short" -> "c", "Long"}` => `Some((FlagSetting::Some("c"), FlagSetting::Automatic))`
	flag_spec: Option<(FlagSetting<char>, FlagSetting<String>)>,
}

enum FlagSetting<T> {
	Some(T),
	None,
	Automatic,
}

//======================================
// Impls
//======================================

impl ClapCommand {
	fn to_clap(&self) -> clap::Command {
		let ClapCommand {
			command_name,
			args,
			subcommands,
			settings,
		} = self;

		let args = args.into_iter().map(ClapArg::to_clap);

		let subcommands = match subcommands {
			Some(subcommands) => {
				subcommands.into_iter().map(ClapCommand::to_clap).collect()
			},
			None => Vec::new(),
		};

		let mut command = clap::Command::new(clap::Id::from(command_name))
			.args(args)
			.subcommands(subcommands);

		if let Some(settings) = settings {
			let ClapCommandSettings {
				arg_required_else_help,
			} = *settings;

			if let Some(value) = arg_required_else_help {
				command = command.arg_required_else_help(value);
			}
		}

		command
	}
}

impl ClapArg {
	fn to_clap(&self) -> clap::Arg {
		let ClapArg {
			arg_name,
			action,
			flag_spec,
		} = self;

		let mut arg = clap::Arg::new(clap::Id::from(arg_name));

		if let Some(action) = action {
			arg = arg.action(action.clone());
		}

		if let Some((short, long)) = flag_spec {
			match short {
				FlagSetting::Some(flag_char) => arg = arg.short(*flag_char),
				FlagSetting::None => (),
				FlagSetting::Automatic => {
					arg = arg.short(
						arg_name
							.chars()
							.next()
							.expect("illegal empty string for command name"),
					)
				},
			}

			match long {
				FlagSetting::Some(flag_name) => arg = arg.long(flag_name),
				FlagSetting::None => (),
				FlagSetting::Automatic => arg = arg.long(arg_name),
			}
		}

		arg
	}
}

//==========================================================
// LibraryLink API
//==========================================================

#[wll::export(wstp, hidden)]
fn load_library_functions(args: Vec<Expr>) -> Expr {
	assert!(args.len() == 0);
	wll::exported_library_functions_association(Some("libclap_link".into()))
}

#[wll::export(wstp)]
fn clap_parse(args: Vec<Expr>) -> Expr {
	assert!(args.len() == 2);

	let Some(cli_args) = args[0].try_as_normal() else {
		panic!("expected 1st argument to be a list of strings, got: {}", args[0])
	};

	if *cli_args.head() != Symbol::new("System`List") {
		panic!(
			"expected 1st argument to be a list of strings, got: {}",
			args[0]
		)
	};

	let cli_args: Vec<&str> = cli_args
		.elements()
		.iter()
		.map(|elem| {
			elem.try_as_str()
				.expect("expected list element to be string")
		})
		.collect();

	let command = ClapCommand::from_expr(&args[1]).unwrap();
	let command: clap::Command = command.to_clap();

	// Save argument metadata for later use in extracting argument match values.
	let arg_metadata: BTreeMap<CommandPath, Vec<ArgMetadata>> =
		extract_arg_metadata(&command);

	//
	// Parse the input CLI arguments using the specified command
	//

	let matches = match command.clone().try_get_matches_from(&cli_args) {
		Ok(matches) => matches,
		Err(err) => {
			return Expr::normal(
				Symbol::new("System`Failure"),
				vec![Expr::string("ClapError"), Expr::string(err.to_string())],
			)
		},
	};

	//
	// Convert the argument matches back into expressions
	//

	let mut command_match_list = Vec::new();

	let mut command_path = vec![command.get_name().to_owned()];
	let mut matches = &matches;

	command_match_list.push(arg_matches_to_expr(
		command.get_name(),
		&arg_metadata[&command_path],
		matches,
	));

	while let Some((subcommand_name, subcommand_matches)) = matches.subcommand()
	{
		command_path.push(subcommand_name.to_owned());

		command_match_list.push(arg_matches_to_expr(
			subcommand_name,
			&arg_metadata[&command_path],
			subcommand_matches,
		));

		matches = subcommand_matches;
	}

	Expr::list(command_match_list)
}

fn arg_matches_to_expr(
	command_name: &str,
	arg_metadata: &[ArgMetadata],
	matches: &clap::ArgMatches,
) -> Expr {
	let mut arg_values = Vec::new();

	// for id in matches.ids() {
	for ArgMetadata { id, action } in arg_metadata {
		let id = id.as_str();

		let missing = Expr::normal(Symbol::new("System`Missing"), vec![]);

		let value: Expr = match action {
			clap::ArgAction::Set => matches
				.get_one::<String>(id)
				.map(Expr::string)
				.unwrap_or(missing),
			clap::ArgAction::Append => matches
				.get_many::<String>(id)
				.map(|values| Expr::list(values.map(Expr::string).collect()))
				.unwrap_or(missing),
			clap::ArgAction::SetTrue | clap::ArgAction::SetFalse => {
				Expr::from(matches.get_flag(id))
			},
			clap::ArgAction::Count => Expr::from(matches.get_count(id)),
			clap::ArgAction::Help | clap::ArgAction::Version => {
				panic!("unsupported special ArgAction: {action:?}")
			},
			other => panic!("unhandled clap argument action kind: {other:?}"),
		};

		arg_values.push(Expr::rule(Expr::string(id), value));
	}

	let arg_values =
		Expr::normal(Symbol::new("System`Association"), arg_values);

	Expr::list(vec![Expr::string(command_name), arg_values])
}

//-------------------------------------

/// Information saved from an [`Arg`][clap::Arg] used to lookup argument matches
/// in [`ArgMatches`][clap::ArgMatches].
#[derive(Debug)]
struct ArgMetadata {
	id: clap::Id,
	action: clap::ArgAction,
}

/// A sequence of command/subcommands in a hierarchy. E.g. `["wolfram", "paclet", "test"]`.
type CommandPath = Vec<String>;

fn extract_arg_metadata(
	command: &clap::Command,
) -> BTreeMap<CommandPath, Vec<ArgMetadata>> {
	fn build_arg_metadata(
		data: &mut BTreeMap<Vec<String>, Vec<ArgMetadata>>,
		parent_command_path: &[String],
		command: &clap::Command,
	) {
		let mut command_path = parent_command_path.to_vec();
		command_path.push(command.get_name().to_owned());

		let metadata: Vec<ArgMetadata> = command
			.get_arguments()
			.map(|arg| ArgMetadata {
				id: arg.get_id().clone(),
				action: arg.get_action().clone(),
			})
			.collect();

		data.insert(command_path.clone(), metadata);

		for subcommand in command.get_subcommands() {
			build_arg_metadata(data, &command_path, subcommand)
		}
	}

	let mut data = BTreeMap::new();
	build_arg_metadata(&mut data, &[], command);
	data
}
