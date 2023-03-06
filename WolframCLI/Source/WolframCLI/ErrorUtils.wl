BeginPackage["ConnorGray`WolframCLI`ErrorUtils`", {
	"ErrorHandling`Experimental`"
}]

RaiseError::usage  = "RaiseError[formatStr, args___] throws a Failure object indicating an error encountered during the build process.";
AddUnmatchedArgumentsHandler::usage = "AddUnmatchedArgumentsHandler[symbol] adds a downvalue to symbol that generates an error when no other downvalues match."

Begin["`Private`"]

CreateErrorType[WolframCLIError, {}]

(*========================================================*)

RaiseError[args___] :=
	Raise[WolframCLIError, args]

(*========================================================*)

AddUnmatchedArgumentsHandler = SetFallthroughError


End[]

EndPackage[]