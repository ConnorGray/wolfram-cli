BeginPackage["ConnorGray`WolframCLI`"]


CommandPacletBuild::usage = "Handle the command `$ wolfram paclet build`."
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

CommandPacletInstall[pacletFile_?StringQ] :=
	doPacletInstall[pacletFile]

(*------------------------------------*)

(* Used by `$ wolfram paclet install` and `$ wolfram paclet build --install` *)
doPacletInstall[pacletFile_?StringQ] := Module[{
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

(*====================================*)

CommandPacletBuild[
	pacletDir: _?StringQ,
	buildDir: _?StringQ | Automatic,
	install: _?BooleanQ
] := Module[{result},

	(* FIXME: Workaround bug: The WolframKernel will crash when loading the
		CodeParser dynamic library if that happens after a call to FileHash[..]
		in PacletBuild (the exact underlying cause is unclear), which manifests
		as wolfram-cli hanging forever waiting for the dead Kernel. *)
	Needs["CodeParser`" -> None];
	CodeParser`CodeConcreteParse["2+2"];

	Needs["PacletTools`" -> None];

	result = PacletTools`PacletBuild[pacletDir, buildDir];

	Replace[result, {
		Success["PacletBuild", KeyValuePattern[{
			"PacletArchive" -> pacletArchive_?StringQ,
			"TotalTime" -> time:Quantity[_, "Seconds"]
		}]] :> (
			Print[AnsiStyle["Build succeeded.", Green], " ", "Took ", ToString[time]];
			Print["Paclet Archive: ", InputForm[pacletArchive]];

			If[install,
				doPacletInstall[pacletArchive]
			]
		),
		failure:Failure[tag_?StringQ] :> (
			Print[Format[failure, TerminalForm]];
		),
		other_ :> (
			Print["PacletBuild result had unexpected format: ", InputForm[other]];
			(* TODO: Standardize on Failure's and how they map to exit codes. *)
			Return[Failure["UnexpectedValue"], Module]
		)
	}]
]

(*====================================*)


End[]

EndPackage[]