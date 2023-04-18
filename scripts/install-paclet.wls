#!/usr/bin/env wolframscript

Needs["PacletTools`"]
Needs["CodeFormatter`"]

Print["Using $InstallationDirectory: ", $InstallationDirectory];

(*-------------------------------------------------------------*)
(* Verify that $repositoryDir is the repository root directory *)
(*-------------------------------------------------------------*)

If[!TrueQ[StringEndsQ[$InputFileName, "install-paclet.wls"]],
	Print["Error: File is not install-paclet.wls"];
	Exit[-1]
]

$repositoryDir = FileNameDrop[$InputFileName, -2]

If[FileNameTake[$repositoryDir] =!= "wolfram-cli",
	Throw[StringForm["Unexpected repository root directory path: ``", $repositoryDir]]
];

(*-------------------------------------------------------------------------------*)
(* Copy the compiled dynamic library into the paclet LibraryResources directory. *)
(*-------------------------------------------------------------------------------*)

WithCleanup[
	SetDirectory[$repositoryDir]
	,
	EchoEvaluation @ RunProcess[{"cargo", "build"}]
	,
	ResetDirectory[]
]

(*-------------------------------------------------------------------------------*)
(* Copy the compiled dynamic library into the paclet LibraryResources directory. *)
(*-------------------------------------------------------------------------------*)

(* FIXME: Make this switch between release and debug builds somehow. *)
Module[{
	source = FileNameJoin[{$repositoryDir, "target", "debug", "libclap_link.dylib"}],
	dest   = FileNameJoin[{$repositoryDir, "WolframCLI", "LibraryResources", $SystemID, "libclap_link.dylib"}]
},
	If[FileExistsQ[dest],
		DeleteFile[dest];
	];

	(* Ensure that the parent LibraryResources/<$SystemID>/ directory exists. *)
	With[{parent = FileNameDrop[dest]},
		If[!DirectoryQ[parent],
			CreateDirectory[parent];
		];
	];

	CopyFile[source, dest]
]

(*---------------------------------------------*)
(* Build the paclet into $repositoryDir/build/ *)
(*---------------------------------------------*)

result = PacletBuild[
	FileNameJoin[{$repositoryDir, "WolframCLI"}],
	FileNameJoin[{$repositoryDir, "build"}]
];

If[MatchQ[result, _Success],
	Print["BUILD RESULT: Success"]
	,
	Print["BUILD RESULT: ", CodeFormat @ ToString[result, InputForm]];
]

If[FailureQ[result],
	Exit[-1];
];

(*------------------------------------*)
(* Install the paclet                 *)
(*------------------------------------*)

pacletFile = result["PacletArchive"];

result = PacletInstall[pacletFile, ForceVersionInstall -> True];

If[MatchQ[result, _PacletObject],
	Print["INSTALL RESULT: PacletObject[..]"]
	,
	Print["INSTALL RESULT: ", CodeFormat @ ToString[result, InputForm]];
]

If[FailureQ[result],
	Exit[-1]
]
