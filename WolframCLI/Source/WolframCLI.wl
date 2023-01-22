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
(*
	Needs["PacletTools`" -> None];

	result = PacletTools`PacletTest[pacletDir, Parallelization -> False];

	Replace[result, {
		(* Print the results in TerminalForm. *)
		groups:{{___TestReportObject}...} :> (
			Scan[
				reports |-> Scan[
					report |-> Module[{results},
						results = Values @ report["TestResults"];

						Assert[MatchQ[results, {___TestResultObject}]];

						Scan[
							Replace[{
								result:TestResultObject[_] :> (
									printTestResult[result];
								),
								other_ :> Throw[StringForm[
									"Unexpected \"TestResults\" element: ``",
									InputForm @ other
								]]
							}],
							results
						];

						(* Print[Format[report, TerminalForm]], *)
					],
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
*)

	(* Print[Format[result, TerminalForm]]; *)

	(* TODO: Base the implementation of this function on PacletTest; currently,
		this implementation is completely ad-hoc. This will depend on adding
		support to PacletTest for passing through EventHandlers for reacting to
		testing events as they happen. *)

	Needs["PacletTools`" -> None];
	Needs["MUnit`" -> None];

	Module[{
		testsDirs,
		testFiles,
		logger
	},
		testsDirs = PacletTools`PacletExtensionDirectory[pacletDir, {"Test", "Tests"}];

		Assert[MatchQ[testsDirs, <| ({"Test" | "Tests", _} -> _?DirectoryQ) ...|>]];

		testsDirs = Values[testsDirs];

		testFiles = Flatten @ Map[
			testsDir |-> FileNames["*.mt" | "*.wlt", testsDir],
			testsDirs
		];

		Assert[MatchQ[testFiles, {___?StringQ}]];

		logger = Function[testResult,
			printTestResult[testResult];
		];

		logger = <|
			"LogSuccess" -> logger,
			"LogFailure" -> logger,
			"LogMessagesFailure" -> logger,
			"LogError" -> logger
		|>;

		Assert[AssociationQ[logger]];

		Scan[
			file |-> (
				Print[AnsiStyle["FILE:", Bold, Underlined], " ", file];
				MUnit`TestRun[file, "Loggers" -> {logger}];
			),
			testFiles
		];
	]
]

(*------------------------------------*)

(*
	Function with argument structure used by the
	"Log(Success|Failure|MessagesFailure|Error)" events.
*)
testOutcomeLogger[test_TestResultObject] := printTestResult[test]

(*------------------------------------*)

printTestResult[test_TestResultObject] := Module[{},
	Replace[test["Outcome"], {
		"Success" :> Print[Format[test, TerminalForm]],
		"Failure" :> Module[{a, b},
			Print[
				Format[test, TerminalForm],
				" -- ",
				AnsiStyle["expected", Red, Italic],
				" | ",
				AnsiStyle["actual", Green, Italic]
			];

			(* Strip the HoldForm wrapper -- this shouldn't be necessary in almost all cases. *)
			a = Replace[test["ExpectedOutput"], HoldForm[x_] :> x];
			b = Replace[test["ActualOutput"], HoldForm[x_] :> x];

			printTextualExprDiff[a, b]
		],
		(* FIXME: Expand this to cover all outcomes *)
		other_ :> (
			Print["Unhandled test failure outcome: ", InputForm[other]];
			$Failed
		)
	}]
]

printTextualExprDiff[
	expr1_,
	expr2_
] := (
	Needs["CodeFormatter`" -> None];

	Module[{
		text1 = CodeFormatter`CodeFormat[ToString[expr1, InputForm], CodeFormatter`Airiness -> 0.8],
		text2 = CodeFormatter`CodeFormat[ToString[expr2, InputForm], CodeFormatter`Airiness -> 0.8],
		alignment
	},
		alignment = SequenceAlignment[
			StringSplit[text1, "\n"],
			StringSplit[text2, "\n"]
		];

		Scan[
			Replace[{
				common:{__?StringQ} :> Print["> ", StringRiffle[common, "\n"]],
				{expected:{___?StringQ}, got:{___?StringQ}} :> (
					Print[AnsiStyle["> ", Red], AnsiStyle[StringRiffle[expected, "\n"], Red]];
					Print[AnsiStyle["> ", Green], AnsiStyle[StringRiffle[got, "\n"], Green]];
				),
				other_ :> Throw[StringForm["Unexpected SequenceAlignment result: ``", InputForm @ other]]
			}],
			alignment
		]
	]
)

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