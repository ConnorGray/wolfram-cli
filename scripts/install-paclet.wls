#!/usr/bin/env wolframscript

If[!TrueQ[StringEndsQ[$InputFileName, "install-paclet.wls"]],
	Exit[-1]
]

repoRootDir = FileNameDrop[$InputFileName, -2]

pacletFile = CreatePacletArchive[FileNameJoin[{
	repoRootDir,
	"WolframCLI"
}]];

result = PacletInstall[pacletFile, ForceVersionInstall -> True];

If[FailureQ[result],
	Exit[-1]
]
