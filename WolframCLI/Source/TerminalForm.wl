BeginPackage["ConnorGray`WolframCLI`TerminalForm`"]

LoadTerminalForm::usage = "LoadTerminalForm[] adds TerminalForm to $OutputForms and loads TerminalForm definitions."

Begin["`Private`"]

Needs["ConnorGray`WolframCLI`"]

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


TerminalStyle[expr_, styles0__] := Module[{
	styles = {styles0},
	codes,
	ansiStyle,
	ansiReset = "\:001b[0m"
},
	codes = Map[ToString @* styleEscapeCode, styles];

	ansiStyle = "\:001b[" <> StringRiffle[codes, ";"] <> "m";

	ToString[Row[{ansiStyle, expr, ansiReset}], OutputForm]
]

styleEscapeCode[style_] := Replace[style, {
	Red | "Red" -> 31,
	Green | "Green" -> 32,
	Blue | "Blue" -> 34,
	Bold | "Bold" -> 1,
	Italic | "Italic" -> 3,
	Underlined | "Underlined" -> 4,
	"SlowBlink" | "Blink" -> 5,
	"FastBlink" -> 6,
	other_ :> Throw[StringForm["Style cannot be represented as ANSI escape code: ``", other]]
}]

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

	Format[failure:Failure[tag_, meta_], TerminalForm] := ToString[TerminalStyle[failure, Red], ScriptForm];

	Format[
		test:TestResultObject[KeyValuePattern[{
			"Outcome" -> outcome_
		}]],
		TerminalForm
	] := Replace[outcome, {
		(* "Failure" :> ToString[TerminalStyle[test, Red]], *)
		"Failure" :> ToString[TestResultObject[TerminalStyle["FAILED", Red]], ScriptForm],
		"Success" :> ToString[TestResultObject[TerminalStyle["OK", Green]], ScriptForm],
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
					TerminalStyle["OK", Green],
					TerminalStyle["FAILED", Red]
				],
				Row[{
					TerminalStyle["OK:", Green],
					" ",
					testsSucceededCount
				}],
				Row[{
					TerminalStyle["FAILED:", Red],
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