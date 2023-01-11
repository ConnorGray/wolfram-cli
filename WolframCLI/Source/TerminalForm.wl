BeginPackage["ConnorGray`WolframCLI`TerminalForm`"]

TerminalForm::usage = "TerminalForm[expr] prints as a character-terminal representation of expr."

LoadTerminalForm::usage = "LoadTerminalForm[] adds TerminalForm to $OutputForms and loads TerminalForm definitions."

AnsiStyle::usage = "AnsiStyle[expr, style] styles expr using the style ANSI color directive."

Begin["`Private`"]

$supported = {
	Failure,
	TestReportObject,
	TestResultObject
}

(* Ensure Failure[..] is fully loaded *before* we add format definitions to
   Failure, since GeneralUtilities` clears all existing definitions when it
   loads. *)
Needs["GeneralUtilities`" -> None]

Needs["MUnit`"]


AnsiStyle[expr_, style_] := Module[{
	ansiStyle,
	ansiReset = "\:001b[0m"
},
	ansiStyle = Replace[style, {
		Red | "Red" -> "\:001b[31m",
		Green | "Green" -> "\:001b[32m",
		other_ :> Throw[StringForm["Unknown ANSI color name: ``", other]]
	}];

	Row[{ansiStyle, expr, ansiReset}]
]

LoadTerminalForm[] := Module[{
	wereProtected
},
WithCleanup[
	wereProtected = Unprotect @@ {$supported};
	Unprotect[{$OutputForms}];
	,

	If[!MemberQ[$OutputForms, TerminalForm],
		AppendTo[$OutputForms, TerminalForm];
	];

	Format[TerminalForm[expr_]] := Format[expr, TerminalForm];

	Format[failure:Failure[tag_, meta_], TerminalForm] := ToString[AnsiStyle[failure, Red], ScriptForm];

	Format[
		test:TestResultObject[KeyValuePattern[{
			"Outcome" -> outcome_
		}]],
		TerminalForm
	] := Replace[outcome, {
		(* "Failure" :> ToString[AnsiStyle[test, Red]], *)
		"Failure" :> ToString[TestResultObject[AnsiStyle["FAILED", Red]], ScriptForm],
		"Success" :> ToString[TestResultObject[AnsiStyle["OK", Green]], ScriptForm],
		_ :> ToString[test]
	}];

	Format[
		report:TestReportObject[KeyValuePattern[{}]],
		TerminalForm
	] := Module[{
		allSucceeded = report["AllTestsSucceeded"],
		testsFailedCount = report["TestsFailedCount"],
		testsSucceededCount = report["TestsSucceededCount"]
	},
		ToString[
			TestReportObject[
				If[TrueQ[allSucceeded],
					AnsiStyle["OK", Green],
					AnsiStyle["FAILED", Red]
				],
				Row[{
					AnsiStyle["OK:", Green],
					" ",
					testsSucceededCount
				}],
				Row[{
					AnsiStyle["FAILED:", Red],
					" ",
					testsFailedCount
				}]
			],
			OutputForm
		]
	];

	(*=====================*)
	(* Generic expressions *)
	(*=====================*)

	(* FIXME:
		Figure out how to make this work. Format[expr, TerminalForm] doesn't
		format List and other expression types that don't explicitly have
		a Format[..] definition assigned, but its not legal to assign
		Format definitions to Protected/Locked System symbols (like List).

		This causes the Command*[] functions to need verbose boilerplate code
		to call Format on the elements of their results need to be printed with
		pretty formatting.
	*)
	(* If no other more specific formatting rules exist, TerminalForm[expr]
	   should be the same as ScriptForm[expr]. *)
	(* Format[expr_, TerminalForm] := Format[expr, ScriptForm] *)
	,
	Protect @@ {wereProtected};
	Protect[$OutputForms];
]]

End[]

EndPackage[]