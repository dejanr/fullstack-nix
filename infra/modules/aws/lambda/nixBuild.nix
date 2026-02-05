{ lib, ... }:

{
  options = {
    flake = lib.mkOption {
      type = lib.types.str;
      description = "Flake reference as 'dir#output' (e.g., 'frontend#lambda'). Dir is relative to project root.";
    };

    outputPath = lib.mkOption {
      type = lib.types.str;
      default = "lambda.zip";
      description = "Path to the lambda archive within the Nix output";
    };
  };
}
