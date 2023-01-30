BeginPackage["ConnorGray`WolframCLI`"]

(*-------------------------------------------------*)
(* Utilities for writing command handler functions *)
(*-------------------------------------------------*)

TerminalStyle::usage = "TerminalStyle[expr, style] styles expr using the style ANSI color directive."

TerminalForm::usage = "TerminalForm[expr] prints as a character-terminal representation of expr."

(*------------------------------------*)
(* Built-in command handler functions *)
(*------------------------------------*)

CommandPacletBuild::usage = "Handle the command `$ wolfram paclet build`."
CommandPacletDoc::usage = "Handle the command `$ wolfram paclet doc`."
CommandPacletInstall::usage = "Handle the command `$ wolfram paclet install`."
CommandPacletTest::usage = "Handle the command `$ wolfram paclet test`."

CommandHandleCustom::usage = "Handle custom subcommands defined by \"WolframCLI\" paclet extensions."

Begin["`Private`"]

Needs["ConnorGray`WolframCLI`"]
Needs["ConnorGray`WolframCLI`ErrorUtils`"]
Needs["ConnorGray`WolframCLI`TerminalForm`"]

(* FIXME: Remove this automatic initialization. *)
LoadTerminalForm[]
SetOptions[$Output, FormatType -> TerminalForm]

(*====================================*)

(* Handle `$ wolfram paclet test` *)
CommandPacletTest[
	pacletDir: _?StringQ
] := Module[{
	result,
	linkObj
},
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

	(*-------------------------------------------------*)
	(* Launch a fresh subkernel for running the tests. *)
	(*-------------------------------------------------*)

	(* By launching a fresh subkernel, we prevent earlier loads of the paclet
	   or other existing Kernel state from contaminating the test run.

	   NOTE:
			This is particularly necessary for making
	        `$ wolfram-cli paclet test` of PacletTools work (or any other paclet
			whose code is loaded by the WolframCLI` implementation).

			In that sense, this code is perhaps a workaround needed only for a
			small number of paclets that WolframCLI` depends on, and it is
			unnecessary for all other paclets.

			TODO: Only launch this subkernel if the specified paclet is one
				loaded by WolframCLI`.
	*)
	linkObj = LinkLaunch[First[$CommandLine] <> " -wstp"];

	MathLink`LinkSetPrintFullSymbols[linkObj, True];

	LinkRead[linkObj]; (* Read the InputNamePacket. *)

	(*--------------------------------------------------------------------*)
	(* Send an expression to drive the test run to the testing subkernel. *)
	(*--------------------------------------------------------------------*)

	LinkWrite[linkObj, Unevaluated @ EvaluatePacket @ Module[{
		testsDirs,
		testFiles,
		logger
	},
		(* Prevent the testing subkernel from adding "\" and ">" characters from
		   wrapping long lines. *)
		SetOptions[$Output, PageWidth -> Infinity];

		(*
			Do PacletDirectoryLoad[pacletDir] first to ensure that the
			specified paclet directory is the paclet actually loaded during
			the test run.

			TODO:
				This can still work incorrectly if the installed version
				of a paclet has a higher version number than the paclet
				in `pacletDir`. Check for that scenario and issue an error
				or at least a warning. (Suggest they do PacletDisable, or
				instead temporarily do that ourselves?)
		*)
		PacletDirectoryLoad[pacletDir];

		Needs["PacletTools`" -> None];
		Needs["MUnit`" -> None];
		Needs["ConnorGray`WolframCLI`" -> None];

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
				Print[TerminalStyle["FILE:", Bold, Underlined], " ", file];
				MUnit`TestRun[file, "Loggers" -> {logger}];
			),
			testFiles
		];
	]];

	(*-------------------------------------------------*)
	(* Process packets sent from the testing subkernel *)
	(*-------------------------------------------------*)

	(* Re-print output sent from the testing subkernel, and close the link once
	   the testing evaluation returns. *)
	While[True,
		Replace[LinkRead[linkObj], {
			packet:TextPacket[output_?StringQ] :> (
				If[!MatchQ[$ParentLink, _LinkObject],
					(* FIXME: Handle this error better. This may occur if/when
						wolfram-cli functionality is moved into WolframKernel,
						where there isn't a parent link. *)
					Throw[Row[{
						"Error forwarding packet from `paclet test` subkernel: $ParentLink is not _LinkObject: ",
						InputForm[$ParentLink]
					}]]
				];

				(* Write[$Output, output]; *)
				(* Forward print output `packet` from the subkernel to the
				   parent client to be printed to the end user. *)
				LinkWrite[$ParentLink, packet];
			),
			MessagePacket[__] :> {},
			ReturnPacket[expr_] :> (
				(* TODO: Do something with `expr`, like print testing summary
					results? *)
				LinkClose[linkObj];
				Break[]
			),
			other_ :> (
				Print["Unexpected packet sent from Kernel during test run: ", InputForm[other]];
				LinkClose[linkObj];
				Break[]
			)
		}];
	];
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
				TerminalStyle["expected", "Red", Italic],
				" | ",
				TerminalStyle["actual", "Green", Italic]
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
					Print[TerminalStyle["> ", "Red"], TerminalStyle[StringRiffle[expected, "\n"], "Red"]];
					Print[TerminalStyle["> ", "Green"], TerminalStyle[StringRiffle[got, "\n"], "Green"]];
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
			Print[TerminalStyle["Successfully installed paclet.", "Green"]];
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
			Print[TerminalStyle["Build succeeded.", "Green"], " ", "Took ", ToString[time]];
			Print["Paclet Archive: ", InputForm[pacletArchive]];

			If[install,
				doPacletInstall[pacletArchive]
			]
		),
		failure:Failure[tag_?StringQ, _] :> (
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

CommandPacletDoc[
	pacletDir: _?StringQ,
	buildDir: _?StringQ | Automatic,
	html: _?BooleanQ,
	open: _?BooleanQ
] := Module[{
	result
},
	Needs["PacletTools`" -> None];

	result = PacletTools`PacletDocumentationBuild[
		pacletDir,
		buildDir,
		Replace[html, {
			True -> "HTML",
			False -> "Notebooks"
		}]
	];

	Replace[result, {
		Success["DocumentationBuild", assoc:KeyValuePattern[{
			"TotalTime" -> Quantity[totalTime_, "Seconds"],
			"PercentSucceeded" -> Quantity[percentSucceeded_, "Percent"],
			"ProcessedFilesCount" -> processedFilesCount_
		}]] :> (
			Print[
				TerminalStyle["Paclet documentation build successful.", "Green"],
				" ",
				"Processed " <> ToString[processedFilesCount] <> " files in " <> ToString[totalTime] <> " seconds."
			];

			If[open && html,
				Replace[Lookup[assoc, "HTMLFiles", {}], {
					{File[htmlFile_?StringQ], ___} :> (
						UsingFrontEnd @ SystemOpen[File[htmlFile]]
					),
					other_ :> (
						Print[Format[Failure["UnexpectedValue", other], TerminalForm]];
					)
				}]
			];
		),
		other_ :> (
			Print[Format[Failure["UnexpectedValue", other], TerminalForm]];
		)
	}];
]

(*====================================*)

CommandHandleCustom[
	(* All command-line arguments. *)
	cliArgs: {___?StringQ}
] := CatchRaised @ Module[{
	subcommand,
	paclets,
	paclet,
	ext,
	handlerSymbol
},
	Needs["PacletTools`" -> None];

	If[Length[cliArgs] < 2,
		(* TODO: Better error. *)
		Throw[$Failed]
	];

	subcommand = cliArgs[[2]];

	(*----------------------------------------------------------------------------*)
	(* Find the paclet and "WolframCLI" extension metadata to handle `subcommand` *)
	(*----------------------------------------------------------------------------*)

	paclets = PacletFind[All, <| "Extension" -> "WolframCLI" |>];

	(* Select paclets that provide a CLI handler for `subcommand`. *)
	paclets = Select[
		paclets,
		paclet |-> Module[{exts},
			exts = PacletTools`PacletExtensions[paclet, "WolframCLI"];
			MemberQ[
				exts,
				{"WolframCLI", KeyValuePattern["Subcommand" -> subcommand]}
			]
		]
	];

	paclet = Replace[paclets, {
		{} :> (
			(* No paclets provide a handler for this subcommand, so indicate to
				the wolfram-cli client that it should show a clap error. *)
			Return["NoCustomHandler", Module]
		),
		{only_} :> only,
		{first_, __} :> (
			Print["ambiguity warning: multiple paclets provide a handler for subcommand: ", paclets];
			first
		),
		other_ :> RaiseError["Unexpected paclet list form: ``", InputForm[paclets]]
	}];

	ext = Replace[PacletTools`PacletExtensions[paclet, "WolframCLI"], {
		{} :> RaiseError["Unreachable: paclet has no WolframCLI extensions"],
		{ext_} :> ext,
		exts:{__} :> (
			Print["ambiguity warning: multiple WolframCLI extensions provide a handler for subcommand: ", InputForm[exts]];
			first
		),
		other_ :> RaiseError["Unexpected PacletExtensions result: ``", InputForm[other]]
	}];

	(*--------------------------------------------------------------------------*)
	(* Extract the "HandlerFunction" option value of the "WolframCLI" extension *)
	(*--------------------------------------------------------------------------*)

	handlerSymbol = Replace[ext, {
		{
			"WolframCLI",
			KeyValuePattern[{
				"Subcommand" -> subcommand,
				"HandlerFunction" -> handlerSymbol0_?StringQ
			}]
		} :> Module[{ctx},
			ctx = StringRiffle[
				Most @ StringSplit[handlerSymbol0, "`"],
				{"", "`", "`"}
			];

			RaiseConfirm @ Needs[ctx];

			Symbol[handlerSymbol0]
		],
		{"WolframCLI", metadata_?AssociationQ} :> RaiseError[
			"\"WolframCLI\" extension did not have the expected fields, or they had invalid values: ``",
			InputForm[ext]
		],
		other_ :> RaiseError["Unexpected extension form: ``", InputForm[other]]
	}];

	(*--------------------------------------------*)
	(* Call the handler function for `subcommand` *)
	(*--------------------------------------------*)

	Replace[handlerSymbol[cliArgs], {
		Null -> Null,
		failure_Failure :> (
			Print[Format[failure, TerminalForm]]
		),
		other_ :> RaiseError[
			"Custom Wolfram CLI handler for subcommand `` returned unexpected result: ``",
			InputForm[subcommand],
			InputForm[other]
		]
	}]
]

(*====================================*)


End[]

EndPackage[]