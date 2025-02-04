# converts path to yaml file -> Nix Object
{ runCommand, remarshal }:
path:
let
  jsonOutputDrv = runCommand "from-yaml" {
    nativeBuildInputs = [ remarshal ];
  } "remarshal -if yaml -i \"${path}\" -of json -o \"$out\"";
in
# perf: importing from / reading a file in a derivation (IFD: Import From Derivation) is known to be slow.
builtins.fromJSON (builtins.readFile jsonOutputDrv)
