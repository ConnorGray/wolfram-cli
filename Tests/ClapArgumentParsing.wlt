Needs["ConnorGray`ClapLink`"]

(*------------------------------------*)
(* Test positional argument parsing   *)
(*------------------------------------*)

With[{
	parser = ClapCommand["foo", {
		ClapArg["x"]
	}]
},
	VerificationTest[
		ClapParse[{"foo"}, parser]
		,
		{{"foo", <| "x" -> Missing[] |>}}
	];

	VerificationTest[
		ClapParse[{"foo", "5"}, parser]
		,
		{{"foo", <| "x" -> "5"|>}}
	];

	VerificationTest[
		ClapParse[{"foo", "5", "10"}, parser]
		,
		Failure["ClapError", <|
			"MessageTemplate" -> "error: unexpected argument '10' found\n\nUsage: foo [x]\n\nFor more information, try '--help'.\n"
		|>]
	];
]

(*--------------------------------------------------------------------*)
(* Test positional argument parsing with multiple non-required args   *)
(*--------------------------------------------------------------------*)

With[{
	parser = ClapCommand["foo", {
		ClapArg["x"],
		ClapArg["y"]
	}]
},
	VerificationTest[
		ClapParse[{"foo"}, parser]
		,
		{{"foo", <| "x" -> Missing[], "y" -> Missing[] |>}}
	];

	VerificationTest[
		ClapParse[{"foo", "5"}, parser]
		,
		{{"foo", <| "x" -> "5", "y" -> Missing[] |>}}
	];

	VerificationTest[
		ClapParse[{"foo", "5", "10"}, parser]
		,
		{{"foo", <| "x" -> "5", "y" -> "10" |>}}
	];
]

(*-------------------------------------*)
(* Test counted flags argument parsing *)
(*-------------------------------------*)

With[{
	parser = ClapCommand["foo", {
		ClapArg["verbose", "Count", {"Short", "Long"}]
	}]
},
	VerificationTest[
		ClapParse[{"foo"}, parser]
		,
		{{"foo", <| "verbose" -> 0 |>}}
	];

	VerificationTest[
		ClapParse[{"foo", "-v"}, parser]
		,
		{{"foo", <| "verbose" -> 1 |>}}
	];

	VerificationTest[
		ClapParse[{"foo", "-vv"}, parser]
		,
		{{"foo", <| "verbose" -> 2 |>}}
	];

	VerificationTest[
		ClapParse[{"foo", "-v", "--verbose"}, parser]
		,
		{{"foo", <| "verbose" -> 2 |>}}
	];

	VerificationTest[
		ClapParse[{"foo", "-vv", "--verbose", "--verbose"}, parser]
		,
		{{"foo", <| "verbose" -> 4 |>}}
	];
]

(*-------------------------------------*)
(* Test boolean flags argument parsing *)
(*-------------------------------------*)

With[{
	parser = ClapCommand["foo", {
		ClapArg["quiet", "SetTrue", {"Short", "Long"}]
	}]
},
	VerificationTest[
		ClapParse[{"foo"}, parser]
		,
		{{"foo", <| "quiet" -> False |>}}
	];

	VerificationTest[
		ClapParse[{"foo", "-q"}, parser]
		,
		{{"foo", <| "quiet" -> True |>}}
	];

	VerificationTest[
		ClapParse[{"foo", "--quiet"}, parser]
		,
		{{"foo", <| "quiet" -> True |>}}
	];
]

With[{
	parser = ClapCommand["foo", {
		ClapArg["bar", "SetFalse", {"Short", "Long"}]
	}]
},
	VerificationTest[
		ClapParse[{"foo"}, parser]
		,
		{{"foo", <| "bar" -> True |>}}
	];

	VerificationTest[
		ClapParse[{"foo", "-b"}, parser]
		,
		{{"foo", <| "bar" -> False |>}}
	];

	VerificationTest[
		ClapParse[{"foo", "--bar"}, parser]
		,
		{{"foo", <| "bar" -> False |>}}
	];
]

(*-------------------------------------*)
(* Test subcommand parsing             *)
(*-------------------------------------*)

With[{
	parser = ClapCommand[
		"foo", {
			ClapArg["verbose", "Count", {"Short", "Long"}]
		}, {
			ClapCommand["bar", {
				ClapArg["file"]
			}]
		}
	]
},
	VerificationTest[
		ClapParse[{"foo"}, parser]
		,
		{{"foo", <| "verbose" -> 0 |>}}
	];

	VerificationTest[
		ClapParse[{"foo", "bar", "TheFile.nb"}, parser]
		,
		{
			{"foo", <| "verbose" -> 0 |>},
			{"bar", <| "file" -> "TheFile.nb" |>}
		}
	];

	VerificationTest[
		ClapParse[{"foo", "-v", "bar", "TheFile.nb"}, parser]
		,
		{
			{"foo", <| "verbose" -> 1 |>},
			{"bar", <| "file" -> "TheFile.nb" |>}
		}
	];
]

(*--------------------------------*)
(* Test ClapCommand settings      *)
(*--------------------------------*)

(* Test "ArgRequiredElseHelp" setting. *)
With[{
	parser = ClapCommand["foo", {}, {
		ClapCommand["bar", {}],
		ClapCommand["baz", {}]
	}, <| "ArgRequiredElseHelp" -> True |>]
},
	VerificationTest[
		ClapParse[{"foo"}, parser]
		,
		Failure["ClapError", <|
			"MessageTemplate" -> "Usage: foo [COMMAND]\n\nCommands:\n  bar   \n  baz   \n  help  Print this message or the help of the given subcommand(s)\n\nOptions:\n  -h, --help  Print help\n"
		|>]
	];

	VerificationTest[
		ClapParse[{"foo", "bar"}, parser]
		,
		{{"foo", <||>}, {"bar", <||>}}
	]
]

(*--------------------------------*)
(* Test the 'greeting.wls' parser *)
(*--------------------------------*)

With[{
	parser = ClapCommand["greeting", {}, {
		ClapCommand["say-hello", {
			ClapArg["name"],
			ClapArg["language", "Set", {"Short", "Long"}]
		}]
	}, <| "ArgRequiredElseHelp" -> True |>]
},
	VerificationTest[
		ClapParse[{"greeting"}, parser]
		,
		Failure["ClapError", <|
			"MessageTemplate" -> "Usage: greeting [COMMAND]\n\nCommands:\n  say-hello  \n  help       Print this message or the help of the given subcommand(s)\n\nOptions:\n  -h, --help  Print help\n"
		|>]
	];

	VerificationTest[
		ClapParse[StringSplit @ "greeting say-hello", parser]
		,
		{
			{"greeting", <||>},
			{"say-hello", <| "name" -> Missing[], "language" -> Missing[] |>}
		}
	];

	VerificationTest[
		ClapParse[StringSplit @ "greeting say-hello Foo", parser]
		,
		{
			{"greeting", <||>},
			{"say-hello", <| "name" -> "Foo", "language" -> Missing[] |>}
		}
	];

	VerificationTest[
		ClapParse[StringSplit @ "greeting say-hello --language Spanish", parser]
		,
		{
			{"greeting", <||>},
			{"say-hello", <| "name" -> Missing[], "language" -> "Spanish" |>}
		}
	];

	VerificationTest[
		ClapParse[StringSplit @ "greeting say-hello Foo --language Spanish", parser]
		,
		{
			{"greeting", <||>},
			{"say-hello", <| "name" -> "Foo", "language" -> "Spanish" |>}
		}
	];
]

(*=====================================*)

elaborateClapArgs = ConnorGray`ClapLink`Private`elaborateClapArgs

VerificationTest[
	elaborateClapArgs @ ClapArg["hello"]
	,
	ClapArg["hello", "Set"]
]

VerificationTest[
	elaborateClapArgs @ ClapArg["hello", "Count", "Short"]
	,
	ClapArg["hello", "Count", {"Short" -> Automatic}]
]

VerificationTest[
	elaborateClapArgs @ ClapArg["hello", "Count", "Short" -> "h"]
	,
	ClapArg["hello", "Count", {"Short" -> "h"}]
]

VerificationTest[
	elaborateClapArgs @ ClapArg["hello", "Count", {"Short", "Long" -> "hi"}]
	,
	ClapArg["hello", "Count", {"Short" -> Automatic, "Long" -> "hi"}]
]

VerificationTest[
	elaborateClapArgs @ ClapArg["verbose", "Count", {"Long", "Short"}]
	,
	ClapArg["verbose", "Count", {"Long" -> Automatic, "Short" -> Automatic}]
]
