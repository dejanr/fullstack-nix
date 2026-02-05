{ lib, name, ... }:

{
  options = {
    name = lib.mkOption {
      type = lib.types.str;
      default = "\${var.project_name}/${name}";
      description = "Secrets Manager secret name (defaults to project_name/key)";
    };

    description = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Secret description";
    };

    kmsKeyId = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "KMS key ID for the secret";
    };

    recoveryWindowInDays = lib.mkOption {
      type = lib.types.int;
      default = 7;
      description = "Recovery window in days";
    };

    initialValue = lib.mkOption {
      type = lib.types.str;
      default = "initialValue";
      description = "Initial secret value (update via AWS CLI after creation)";
    };

    createInitialVersion = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Create an initial secret version";
    };

    fetchValue = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Fetch the secret value via data source (for use in other resources)";
    };

    tags = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Tags for the secret";
    };
  };
}
