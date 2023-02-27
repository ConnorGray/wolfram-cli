mod from_expr;

use std::panic::{self, AssertUnwindSafe};

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
		} = self;

		let args = args.into_iter().map(ClapArg::to_clap);

		let subcommands = match subcommands {
			Some(subcommands) => {
				subcommands.into_iter().map(ClapCommand::to_clap).collect()
			},
			None => Vec::new(),
		};

		clap::Command::new(clap::Id::from(command_name))
			.args(args)
			.subcommands(subcommands)
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

	let matches = match command.clone().try_get_matches_from(&cli_args) {
		Ok(matches) => matches,
		Err(err) => {
			return {
				Expr::normal(
					Symbol::new("System`Failure"),
					vec![
						Expr::string("ClapError"),
						Expr::string(err.to_string()),
					],
				)
			}
		},
	};

	let mut command_match_list = Vec::new();

	let mut matches = &matches;

	command_match_list.push(arg_matches_to_expr(command.get_name(), matches));

	while let Some((subcommand_name, subcommand_matches)) = matches.subcommand()
	{
		command_match_list
			.push(arg_matches_to_expr(subcommand_name, subcommand_matches));
		matches = subcommand_matches;
	}

	Expr::list(command_match_list)
}

fn arg_matches_to_expr(command_name: &str, matches: &clap::ArgMatches) -> Expr {
	let mut arg_values = Vec::new();

	for id in matches.ids() {
		let id = id.as_str();

		// FIXME:
		//     This uses of catch_unwind() below are necessary as a workaround
		//     for the fact that there are no try_get_count() and
		//     try_get_flag() methods on ArgMatches.
		//
		//     Fix this properly by either recording the ArgAction so that we
		//     can directly call the appropriate method, or submit a PR adding
		//     the necessary try_*() methods into clap.
		let value: Expr =
			if let Ok(Some(values)) = matches.try_get_many::<String>(id) {
				let values = values.map(Expr::string).collect();
				Expr::list(values)
			} else if let Ok(count) =
				panic::catch_unwind(AssertUnwindSafe(|| matches.get_count(id)))
			{
				Expr::from(count)
			} else if let Ok(is_set) =
				panic::catch_unwind(AssertUnwindSafe(|| matches.get_flag(id)))
			{
				Expr::from(is_set)
			} else {
				panic!("unknown argument type: {id}")
			};

		arg_values.push(Expr::rule(Expr::string(id), value));
	}

	let arg_values =
		Expr::normal(Symbol::new("System`Association"), arg_values);

	Expr::list(vec![Expr::string(command_name), arg_values])
}

//======================================
// Types
//======================================
