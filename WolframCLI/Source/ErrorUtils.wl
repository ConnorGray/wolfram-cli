BeginPackage["ConnorGray`WolframCLI`ErrorUtils`"]

RaiseError::usage  = "RaiseError[formatStr, args___] throws a Failure object indicating an error encountered during the build process.";
RaiseConfirm
RaiseAssert::usage = "RaiseAssert[cond, formatStr, args___] throws a Failure object indicating a failed assertion encountered during the build process.";
CatchRaised::usage = "CatchRaised[expr] catches all exceptions raised with Raise* functions.";
AddUnmatchedArgumentsHandler::usage = "AddUnmatchedArgumentsHandler[symbol] adds a downvalue to symbol that generates an error when no other downvalues match."
$RaiseErrorTag

$ExitOnExceptionPreHandler

RaiseError::error = "``"
RaiseAssert::assertfail = "``"

Begin["`Private`"]

(*========================================================*)

$ExitOnExceptionPreHandler = Function[
	expr,
	Module[{result},
		result = Catch[expr, _, "UncaughtException"];
		If[Head[result] === "UncaughtException",
			Print["Terminating program due to uncaught exception."];
			Exit[];
		]
	],
	HoldFirst
];

(*========================================================*)

$RaiseErrorTag

(* Generate a message and an exception. *)
RaiseError[formatStr_?StringQ, args___] := (
	Message[
		RaiseError::error,
		(* Note: Use '@@' to avoid behavior described in bug #240412. *)
		ToString[StringForm @@ {formatStr, args}]
	];

	Throw[
		Failure["PackagesError", <|
			"MessageTemplate" -> formatStr,
			"MessageParameters" -> {args}
		|>],
		$RaiseErrorTag
	]
)

RaiseError[failure: _Failure] := (
	Throw[failure, $RaiseErrorTag]
)

RaiseError[args___] := Throw[
	Failure["PackagesError", <|
		"MessageTemplate" -> ToString[StringForm[
		"Unknown error occurred: ``",
		StringJoin[Map[ToString, {args}]]
		]]
	|>],
	$RaiseErrorTag
]

(*========================================================*)

Attributes[RaiseConfirm] = {HoldFirst}

RaiseConfirm[expr_] := Module[{result},
	result = expr;

	If[FailureQ[result] || MissingQ[result],
		RaiseError["RaiseConfirm error evaluating ``: ``", HoldForm[expr], result];
	];

	result
];

(*========================================================*)

Attributes[RaiseAssert] = {HoldFirst}

RaiseAssert[
	cond_,
	formatStr : _?StringQ,
	args___
] := If[!TrueQ[cond],
	Message[
		RaiseAssert::assertfail,
		(* Note: Use '@@' to avoid behavior described in bug #240412. *)
		"RaiseAssert[..] failed: " <> ToString[StringForm @@ {formatStr, args}]
	];

	Throw[
		Failure["PackagesError", <|
			"MessageTemplate" -> "RaiseAssert[..] failed: " <> formatStr,
			"MessageParameters" -> {args}
		|>],
		$RaiseErrorTag
	]
]

RaiseAssert[cond_] :=
	RaiseAssert[
		cond,
		"RaiseAssert[..] of expression failed: ``",
		(* HoldForm so that the error shows the unevaluated asserted expression. *)
		HoldForm @ InputForm @ cond
	]

RaiseAssert[args:PatternSequence[Optional[cond_, Sequence[]], ___]] := Throw[
	Failure["PackagesError", <|
		"MessageTemplate" -> ToString[StringForm[
			"Malformed RaiseAssert[``, ...] call: ``",
			HoldForm @ InputForm @ cond,
			StringJoin[Riffle[Map[ToString, {args}], ", "]]
		]]
	|>],
	$RaiseErrorTag
]

(*========================================================*)

Attributes[CatchRaised] := {HoldFirst}

CatchRaised[expr_] := Catch[expr, $RaiseErrorTag]

(*========================================================*)

Attributes[AddUnmatchedArgumentsHandler] = {HoldFirst}

AddUnmatchedArgumentsHandler[symbol_Symbol] := (
	symbol[args___] := RaiseError[
		"``: unrecognized arguments: ``",
		ToString[Unevaluated[symbol]],
		InputForm[{args}]
	]
)

End[]

EndPackage[]