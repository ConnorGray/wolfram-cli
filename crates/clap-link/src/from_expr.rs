use wolfram_library_link::expr::{symbol::SymbolRef, Expr, Normal, Symbol};

use crate::{ClapArg, ClapCommand, ClapCommandSettings, FlagSetting};

//======================================
// FromExpr implementations
//======================================

pub(crate) trait FromExpr: Sized {
	fn from_expr(expr: &Expr) -> Result<Self, String>;
}

impl FromExpr for ClapCommand {
	fn from_expr(expr: &Expr) -> Result<Self, String> {
		let elements = try_normal_with_head(
			expr,
			SymbolRef::try_new("ConnorGray`ClapLink`ClapCommand").unwrap(),
		)?;

		let (command_name, args, subcommands, settings) = match elements {
			[command_name, args] => (command_name, args, None, None),
			[command_name, args, subcommands] => {
				(command_name, args, Some(subcommands), None)
			},
			[command_name, args, subcommands, settings] => {
				(command_name, args, Some(subcommands), Some(settings))
			},
			_ => {
				return Err(format!(
					"ClapCommand has wrong number of arguments: {}.",
					elements.len()
				))
			},
		};

		let command_name: String = command_name
			.try_as_str()
			.expect("expected 1st element to be a String")
			.to_owned();

		let args = try_normal_with_head(
			args,
			SymbolRef::try_new("System`List").unwrap(),
		)?;

		let args = args
			.into_iter()
			.map(ClapArg::from_expr)
			.collect::<Result<Vec<ClapArg>, String>>()?;

		let subcommands = match subcommands {
			Some(subcommands) => {
				let subcommands = try_normal_with_head(
					subcommands,
					SymbolRef::try_new("System`List").unwrap(),
				)?;

				let subcommands = subcommands
					.iter()
					.map(ClapCommand::from_expr)
					.collect::<Result<Vec<_>, String>>()?;

				Some(subcommands)
			},
			None => None,
		};

		let settings = match settings {
			Some(settings) => {
				let rules = try_normal_with_head(
					settings,
					SymbolRef::try_new("System`Association").unwrap(),
				)?;

				let mut settings = ClapCommandSettings {
					arg_required_else_help: None,
				};

				for rule in rules {
					let [lhs, rhs] = try_normal_array_with_head(
						rule,
						SymbolRef::try_new("System`Rule").unwrap(),
					)?;

					match lhs.try_as_str() {
						Some("ArgRequiredElseHelp") => {
							let bool = rhs.try_as_bool().expect(
								"expected boolean ClapCommand setting value",
							);
							settings.arg_required_else_help = Some(bool);
						},
						_ => panic!("unknown ClapCommand setting name: {lhs}"),
					}
				}

				Some(settings)
			},
			None => None,
		};

		Ok(ClapCommand {
			command_name,
			args,
			subcommands,
			settings,
		})
	}
}

impl FromExpr for ClapArg {
	fn from_expr(expr: &Expr) -> Result<Self, String> {
		let elements = try_normal_with_head(
			expr,
			SymbolRef::try_new("ConnorGray`ClapLink`ClapArg").unwrap(),
		)?;

		let (arg_name, action, flag_spec) = match elements {
			[arg_name] => (arg_name, None, None),
			[arg_name, action] => (arg_name, Some(action), None),
			[arg_name, action, flag_spec] => {
				(arg_name, Some(action), Some(flag_spec))
			},
			_ => return Err(format!("ClapArg has wrong number of arguments")),
		};

		let arg_name: String = arg_name
			.try_as_str()
			.expect("expected 1st element to be a String")
			.to_owned();

		let action: Option<clap::ArgAction> = match action {
			Some(action) => {
				let action = action
					.try_as_str()
					.expect("expected argument action to be a String");
				let action = match action {
					"Set" => clap::ArgAction::Set,
					"Append" => clap::ArgAction::Append,
					"SetTrue" => clap::ArgAction::SetTrue,
					"SetFalse" => clap::ArgAction::SetFalse,
					"Count" => clap::ArgAction::Count,
					other => panic!(
						"unrecognized ClapArg arg action variant: {other}"
					),
				};
				Some(action)
			},
			None => None,
		};

		let flag_spec: Option<_> = match flag_spec {
			Some(flag_spec) => {
				let specs = try_normal_with_head(
					flag_spec,
					SymbolRef::try_new("System`List").unwrap(),
				)?;

				let mut short = FlagSetting::None;
				let mut long = FlagSetting::None;

				for spec in specs {
					let [lhs, rhs] = try_normal_array_with_head(
						spec,
						SymbolRef::try_new("System`Rule").unwrap(),
					)?;

					let value = if *rhs == Symbol::new("System`Automatic") {
						FlagSetting::Automatic
					} else if let Some(string) = rhs.try_as_str() {
						FlagSetting::Some(string.to_owned())
					} else {
						panic!("unexpected flag setting value (expected a String or Automatic): {rhs}")
					};

					match lhs.try_as_str() {
						Some("Short") => match value {
							FlagSetting::Some(string) => {
								// FIXME:
								//     What if string contains more than 1 char?
								//     Currently those extra chars are silently
								//     ignored.
								let c = string.chars().next().expect(
									"illegal empty string for Arg short flag",
								);

								short = FlagSetting::Some(c);
							},
							FlagSetting::None => short = FlagSetting::None,
							FlagSetting::Automatic => {
								short = FlagSetting::Automatic
							},
						},
						Some("Long") => long = value,
						other => panic!("invalid flag value (expected 'Short' or 'Long'): {other:?}"),
					};
				}

				Some((short, long))
			},
			None => None,
		};

		Ok(ClapArg {
			arg_name,
			action,
			flag_spec,
		})
	}
}

//======================================
// Utilities
//======================================

fn try_normal(expr: &Expr) -> Result<&Normal, String> {
	expr.try_as_normal()
		.ok_or_else(|| format!("expected Normal expression, got: {expr}"))
}

fn try_normal_with_head<'e>(
	expr: &'e Expr,
	expected_head: SymbolRef,
) -> Result<&'e [Expr], String> {
	let normal = try_normal(expr)?;

	if *normal.head() == expected_head.to_symbol() {
		Ok(normal.elements())
	} else {
		Err(format!(
			"expected Normal expression with head '{}', got head '{}'",
			expected_head.as_str(),
			normal.head()
		))
	}
}

fn try_normal_array_with_head<'e, const N: usize>(
	expr: &'e Expr,
	expected_head: SymbolRef,
) -> Result<&'e [Expr; N], String> {
	let elements = try_normal_with_head(expr, expected_head)?;

	match elements.try_into() {
		Ok(array) => Ok(array),
		Err(_) => Err(format!(
			"expected Normal expression with length {N}, got {} elements",
			elements.len()
		)),
	}
}
