#!/usr/bin/env wolframscript

(*
	Example: greeting.wls

	$ ./greeting.wls

	$ ./greeting.wls say-hello

	$ ./greeting.wls say-hello Foo

	$ ./greeting.wls say-hello Foo Bar

	$ ./greeting.wls say-hello --language Spanish

	$ ./greeting.wls say-hello Foo --language Spanish
*)

Needs["ConnorGray`ClapLink`"]
Needs["ConnorGray`WolframCLI`" -> "CLI`"]

CLI`LoadTerminalForm[]

(* NOTE:
	When changing this, please also update the copy in ClapArgumentParsing.wlt *)
parser = ClapCommand["greeting", {}, {
	ClapCommand["say-hello", {
		ClapArg["name"],
		ClapArg["language", "Set", {"Short", "Long"}]
	}]
}, <| "ArgRequiredElseHelp" -> True |>]

Replace[ClapParse[$ScriptCommandLine, parser], {
	error_Failure :> Print[error],
	{
		{"greeting", _},
		{"say-hello", KeyValuePattern[{
			"name" -> name0:(_?StringQ | _?MissingQ),
			"language" -> lang:(_?StringQ | _?MissingQ)
		}]}
	} :> Module[{
		name = Replace[name0, _?MissingQ :> $Username],
		hello
	},
		hello = Replace[lang, {
			_?MissingQ | "English" -> "Hello",
			other_ :> TextTranslation["Hello", "English" -> other]
		}];
		Print[hello, ", ", CLI`TerminalStyle[name, Bold, Underlined]]
	],
	other_ :> Print[CLI`TerminalStyle["Error: unexpected CLI parse result:", "Red"], " ", InputForm[other]]
}]
