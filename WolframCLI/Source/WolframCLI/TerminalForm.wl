BeginPackage["ConnorGray`WolframCLI`TerminalForm`"]

LoadTerminalForm::usage = "LoadTerminalForm[] adds TerminalForm to $OutputForms and loads TerminalForm definitions."

Begin["`Private`"]

Needs["ConnorGray`WolframCLI`"]
Needs["ConnorGray`WolframCLI`ErrorUtils`"]

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

TerminalStyle[expr_] := ToString[expr, OutputForm]

TerminalStyle[expr_, styles0__] := Module[{
	styles = {styles0},
	codes,
	ansiStyle,
	ansiReset = "\:001b[0m",
	exprLines = StringSplit[ToString[expr, OutputForm], "\n"]
},
	codes = Map[ToString @* styleEscapeCode, styles];

	ansiStyle = "\:001b[" <> StringRiffle[codes, ";"] <> "m";

	StringRiffle[
		Map[
			line |-> ansiStyle <> line <> ansiReset,
			exprLines
		],
		"\n"
	]
]

styleEscapeCode[style_] := Replace[style, {
	(* Named Colors, foreground *)
	"Black" -> 30,
	"Red" -> 31,
	"Green" -> 32,
	"Yellow" -> 33,
	"Blue" -> 34,
	"Magenta" -> 35,
	"Cyan" -> 36,
	"White" -> 37,

	"BrightBlack" | "Gray" -> 90,
	"BrightRed" -> 91,
	"BrightGreen" -> 92,
	"BrightYellow" -> 93,
	"BrightBlue" -> 94,
	"BrightMagenta" -> 95,
	"BrightCyan" -> 96,
	"BrightWhite" -> 97,

	(* Named Colors, background *)
	(Background -> "Black") -> 40,
	(Background -> "Red") -> 41,
	(Background -> "Green") -> 42,
	(Background -> "Yellow") -> 43,
	(Background -> "Blue") -> 44,
	(Background -> "Magenta") -> 45,
	(Background -> "Cyan") -> 46,
	(Background -> "White") -> 47,

	(Background -> ("BrightBlack" | "Gray")) -> 40,
	(Background -> "BrightRed") -> 41,
	(Background -> "BrightGreen") -> 42,
	(Background -> "BrightYellow") -> 43,
	(Background -> "BrightBlue") -> 44,
	(Background -> "BrightMagenta") -> 45,
	(Background -> "BrightCyan") -> 46,
	(Background -> "BrightWhite") -> 47,

	(* TODO: Strings should be ANSI standard; RGBColor's should use true color. *)

	Bold | "Bold" -> 1,
	Italic | "Italic" -> 3,
	Underlined | "Underlined" -> 4,
	"SlowBlink" | "Blink" -> 5,
	"FastBlink" -> 6,

	other_ :> RaiseError[
		"Style directive cannot be represented as ANSI escape code: ``",
		InputForm[other]
	]
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

	(*---------*)
	(* Failure *)
	(*---------*)

	(* Format Failure's that contain a "CausedBy" field to print both the
	   outer error and the inner 'cause' error.

	   Note that this is recursive, so a chain of "CausedBy" errors will be
	   formatted with each cause on a separate line. *)
	Format[
		Failure[tag_, assoc:KeyValuePattern[{"CausedBy" -> cause_Failure}]],
		TerminalForm
	] := StringJoin[
		(* Drop "CausedBy" to prevent infinite recursion. *)
		ToString @ Format[Failure[tag, KeyDrop[assoc, "CausedBy"]], TerminalForm],
		"\n  | Caused by: ",
		ToString @ Format[cause, TerminalForm]
	];

	Format[failure:Failure[tag_, meta_], TerminalForm] := ToString[TerminalStyle[failure, "Red"], ScriptForm];

	(*------------------*)
	(* TestResultObject *)
	(*------------------*)

	Format[
		test:TestResultObject[KeyValuePattern[{
			"Outcome" -> outcome_
		}]],
		TerminalForm
	] := Replace[outcome, {
		(* "Failure" :> ToString[TerminalStyle[test, Red]], *)
		"Failure" :> ToString[TestResultObject[TerminalStyle["Failure", "Red"]], ScriptForm],
		"Success" :> ToString[TestResultObject[TerminalStyle["OK", "Green"]], ScriptForm],
		"Error"   :> ToString[TestResultObject[TerminalStyle["Error", "Red", Underlined]], ScriptForm],
		"MessagesFailure" :> ToString[TestResultObject[TerminalStyle["MessagesFailure", "Yellow"]], ScriptForm],
		_ :> ToString[test]
	}];

	Format[
		report:TestReportObject[KeyValuePattern[{}]],
		TerminalForm
	] := Module[{
		allSucceeded = report["AllTestsSucceeded"],
		testsSucceededCount = report["TestsSucceededCount"],
		testsFailedCount = report["TestsFailedCount"],
		testsFailedWithErrorsCount = report["TestsFailedWithErrorsCount"]
	},
		ToString[
			TestReportObject[
				If[TrueQ[allSucceeded],
					TerminalStyle["OK", "Green"],
					TerminalStyle["FAILED", "Red"]
				],
				Row[{
					TerminalStyle["ok:", "Green"],
					" ",
					testsSucceededCount
				}],
				Row[{
					TerminalStyle["failed:", "Red"],
					" ",
					testsFailedCount
				}],
				Row[{
					TerminalStyle["error:", "Red"],
					" ",
					testsFailedWithErrorsCount
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