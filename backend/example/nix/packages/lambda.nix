{ pkgs }:

let
  example = import ./example.nix { inherit pkgs; };
in
pkgs.runCommand "backend-example-lambda" { nativeBuildInputs = [ pkgs.zip ]; } ''
  mkdir -p $out
  cp ${example}/bin/example $out/bootstrap
  cd $out && zip -r lambda.zip bootstrap
  rm bootstrap
''
