BeginPackage["ConnorGray`WolframCLI`"]


CommandPacletTest::usage = "Handle the command `$ wolfram paclet test`."

Begin["`Private`"]

Needs["ConnorGray`WolframCLI`TerminalForm`"]

(* FIXME: Remove this automatic initialization. *)
LoadTerminalForm[]
SetOptions[$Output, FormatType -> TerminalForm]

(*====================================*)

(* Handle `$ wolfram paclet test` *)
CommandPacletTest[
	pacletDir: _?StringQ
] := Module[{},
	Needs["PacletTools`" -> None];

	result = PacletTools`PacletTest[pacletDir, Parallelization -> False];

	Replace[result, {
		(* Print the results in TerminalForm. *)
		{reports:{___TestReportObject}} :> (
			Scan[
				report |-> Print[Format[report, TerminalForm]],
				reports
			];

			If[AllTrue @ Map[report |-> report["AllTestsSucceeded"], reports],
				Success["AllTestsSucceeded"],
				Failure["TestsFailed"]
			]
		),
		other_ :> (
			Print["PacletTest result had unexpected format: ", InputForm[other]];
			(* TODO: Standardize on Failure's and how they map to exit codes. *)
			Return[Failure["UnexpectedValue"], Module]
		)
	}];

	(* Print[Format[result, TerminalForm]]; *)
]

(*====================================*)


End[]

EndPackage[]