{ lib, config, ... }:

let
  cfg = config.aws.secretsmanager;
  sanitizeName = name: builtins.replaceStrings [ "-" "." ] [ "_" "_" ] name;
  secrets = cfg.secrets;
  secretsWithVersion = lib.filterAttrs (_: secret: secret.createInitialVersion) secrets;
  secretsWithFetch = lib.filterAttrs (_: secret: secret.fetchValue) secrets;
  hasSecrets = secrets != { };
in
{
  options.aws.secretsmanager = {
    secrets = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule (import ./secret.nix));
      description = "Secrets Manager secrets";
      default = { };
    };

    tags = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Tags to apply to all secrets";
    };
  };

  config = lib.mkIf hasSecrets {
    data.aws_secretsmanager_secret_version = lib.mapAttrs' (
      name: secret:
      let
        resourceName = sanitizeName name;
      in
      lib.nameValuePair resourceName {
        secret_id = "\${aws_secretsmanager_secret_version.${resourceName}.secret_id}";
      }
    ) secretsWithFetch;

    resource.aws_secretsmanager_secret = lib.mapAttrs' (
      name: secret:
      let
        resourceName = sanitizeName name;
      in
      lib.nameValuePair resourceName (
        {
          name = secret.name;
          description = secret.description;
          recovery_window_in_days = secret.recoveryWindowInDays;
          tags = cfg.tags // secret.tags;
        }
        // lib.optionalAttrs (secret.kmsKeyId != null) {
          kms_key_id = secret.kmsKeyId;
        }
      )
    ) secrets;

    resource.aws_secretsmanager_secret_version = lib.mapAttrs' (
      name: secret:
      let
        resourceName = sanitizeName name;
      in
      lib.nameValuePair resourceName {
        secret_id = "\${aws_secretsmanager_secret.${resourceName}.id}";
        secret_string = secret.initialValue;
      }
    ) secretsWithVersion;

    output.secretsmanager_secret_arns = {
      description = "Secrets Manager secret ARNs";
      value = lib.mapAttrs (
        name: _: "\${aws_secretsmanager_secret.${sanitizeName name}.arn}"
      ) secrets;
    };

    output.secretsmanager_secret_names = {
      description = "Secrets Manager secret names";
      value = lib.mapAttrs (
        name: secret: secret.name
      ) secrets;
    };
  };
}
