BeginPackage["TravelDirectionsCLI`"]

HandleTravelDirectionsSubcommand

Begin["`Private`"]

Needs["ConnorGray`WolframCLI`" -> "CLI`"];

HandleTravelDirectionsSubcommand[
	cliArgs: {___?StringQ}
] := Module[{
	locations,
	dataset,
	index
},
	Replace[cliArgs, {
		{_, "travel-directions", Repeated[_, {0, 1}]} :> (
			Return @ Failure["TravelDirectionsCLI", "expected at least 2 location arguments"];
		),
		{_, "travel-directions", locations0:Repeated[_, {2, Infinity}]} :> (
			locations = {locations0};
		),
		other_ :> (
			Return @ Failure["TravelDirectionsCLI", ToString @ StringForm[
				"unexpected CLI arguments: ``",
				InputForm[other]
			]];
		)
	}];

	dataset = Replace[TravelDirections[locations, "Dataset"], {
		data_Dataset :> data,
		other_ :> (
			Return @ Failure["TravelDirectionsCLI", ToString @ StringForm[
				"unexpected TravelDirections[..] result: ``",
				InputForm[other]
			]];
		)
	}];

	Print[CLI`TerminalStyle["Start:", "Blue", Underlined], " ", First[locations]];

	index = 1;

	Scan[
		Function[
			Print[
				CLI`TerminalStyle[ToString[index] <> ".", Bold],
				" ",
				#Description,
				" (",
				CLI`TerminalStyle[#Distance, "Green"],
				")"
			];

			index += 1;
		],
		Normal[dataset]
	];

	Print[CLI`TerminalStyle["End:", "Green", Underlined], " ", Last[locations]];
]


End[] (* End `Private` *)

EndPackage[]
