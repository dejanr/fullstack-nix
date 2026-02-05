{ lib, name, ... }:

{
  options = {
    name = lib.mkOption {
      type = lib.types.str;
      default = "\${var.project_name}-${name}-role";
      description = "IAM role name (defaults to project_name-key-role)";
    };

    policyStatements = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule (import ./policyStatement.nix));
      default = [ ];
      description = "Inline policy statements";
    };

    attachBasicExecution = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Attach AWSLambdaBasicExecutionRole policy";
    };

    tags = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Tags for the role";
    };
  };
}
