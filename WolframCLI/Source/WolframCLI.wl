BeginPackage["ConnorGray`WolframCLI`"]


CommandPacletInstall::usage = "Handle the command `$ wolfram paclet install`."
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
] := Module[{result},
	Needs["PacletTools`" -> None];

	result = PacletTools`PacletTest[pacletDir, Parallelization -> False];

	Replace[result, {
		(* Print the results in TerminalForm. *)
		groups:{{___TestReportObject}...} :> (
			Scan[
				reports |-> Scan[
					report |-> Print[Format[report, TerminalForm]],
					reports
				],
				groups
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

CommandPacletInstall[pacletFile_?StringQ] := Module[{
	(* TODO: Expose this ForceVersionInstall value via the command-line
	         interface? *)
	result = PacletInstall[pacletFile, ForceVersionInstall -> True]
},
	Replace[result, {
		HoldPattern @ PacletObject[_] :> (
			Print[AnsiStyle["Successfully installed paclet.", Green]];
		),
		failure_?FailureQ :> (
			Print["Error installing paclet: ", Format[failure, TerminalForm]];
			failure
		),
		other_ :> (
			Print["PacletInstall result had unexpected format: ", InputForm[other]];
			Return[Failure["UnexpectedValue"], Module]
		)

	}]
]


End[]

EndPackage[]