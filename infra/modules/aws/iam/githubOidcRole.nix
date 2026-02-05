{ lib, ... }:

{
  options = {
    name = lib.mkOption {
      type = lib.types.str;
      description = "IAM role name";
    };

    subjects = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "OIDC subject claims allowed to assume the role";
    };

    policyStatements = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule (import ./policyStatement.nix));
      default = [ ];
      description = "Inline policy statements";
    };

    tags = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Tags for the role";
    };
  };
}
