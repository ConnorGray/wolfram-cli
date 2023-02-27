BeginPackage["ConnorGray`ClapLink`"]

Needs["GeneralUtilities`" -> "GU`"]

GU`SetUsage[ClapCommand, "
ClapCommand[name$, args$, subcommands$]
"]

ClapArg[ClapArg, "
ClapArg[name$]
ClapArg[name$, action$]
ClapArg[name$, action$, flag$] represents an argument with a named flag.
"]

ClapArg[ClapParse, "
ClapParse[args$, command$]
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