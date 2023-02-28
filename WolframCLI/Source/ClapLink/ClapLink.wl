BeginPackage["ConnorGray`ClapLink`"]

Needs["GeneralUtilities`" -> "GU`"]

GU`SetUsage[ClapCommand, "
ClapCommand[name$, arguments$] represents a command-line command with the specified args$.
ClapCommand[name$, arguments$, subcommands$] represents a command-line command with the specified args$ and subcommands$.

arguments$ must be a list of ClapArg[\[Ellipsis]].

If specified, subcommands$ must be a list of ClapCommand[\[Ellipsis]].
"]

GU`SetUsage[ClapArg, "
ClapArg[name$] represents a positional command-line argument.
ClapArg[name$, action$] represents a positional argument whose values are processed as specified by action$.
ClapArg[name$, action$, flag$] represents an optional argument specified with a named flag.

action$ must be a string that names one of the clap::ArgAction enum variants.

If flag$ is either \"Short\", \"Long\", or the list {\"Short\", \"Long\"}, the
specified argument is optional, and must be specified using the syntax for
short ('-X') and long ('--XXX') options, respectively.

Specify flag$ as \"Short\" -> \"char$\", or \"Long\" -> \"\[Ellipsis]$\" to
override the default short and long option names, which are otherwise,
respectively, the same as the first character in name$, and the same as name$.
"]

GU`SetUsage[ClapParse, "
ClapParse[args$, command$] parses the command line arguments in args$ using command$.
"]

Begin["`Private`"]

Needs["ErrorHandling`Experimental`"]

(*====================================*)

$functions = LibraryFunctionLoad["libclap_link", "load_library_functions", LinkObject, LinkObject][]

RaiseAssert[MatchQ[$functions, <| (_?StringQ -> _LibraryFunction | _Function)... |>]]

(*====================================*)

ClapParse[
	args:{___?StringQ},
	command_ClapCommand
] := $functions["clap_parse"][args, elaborateClapArgs @ command]

SetFallthroughError[ClapParse]

(*====================================*)

elaborateClapArgs[expr_] :=
	ReplaceAll[expr, {
		ClapArg[name_?StringQ] :> ClapArg[name, "Set"],
		arg:ClapArg[name_?StringQ, action_?ArgActionQ] :> arg,
		(* Canonicalize the 3rd argument. *)
		ClapArg[
			name_?StringQ,
			action_?StringQ,
			flagSpec_
		] :> ClapArg[name, action, elaborateFlagSpec[flagSpec]]
	}]

(*------------------------------------*)

elaborateFlagSpec[flag:("Long" | "Short")] :=
	{flag -> Automatic}
elaborateFlagSpec[flag:("Long" | "Short") -> flagValue_?StringQ] :=
	{flag -> flagValue}

elaborateFlagSpec[list_?ListQ] := Flatten @ Map[elaborateFlagSpec, list]

elaborateFlagSpec[other_] := other

(*====================================*)

ArgActionQ[expr_] := MatchQ[
	expr,
	"Set" | "Append" | "SetTrue" | "SetFalse" | "Count" | "Help" | "Version"
]

SetFallthroughError[ArgActionQ]



End[]

EndPackage[]