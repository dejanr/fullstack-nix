{ lib, name, config, ... }:

{
  options = {
    name = lib.mkOption {
      type = lib.types.str;
      default = "\${var.project_name}-${name}";
      description = "S3 bucket name (defaults to project_name-key)";
    };

    forceDestroy = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Allow deletion of non-empty buckets";
    };

    versioning = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable bucket versioning";
    };

    publicRead = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Allow public reads";
    };

    publicPolicy = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Attach a public bucket policy when publicRead is enabled";
    };

    objectOwnership = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = if config.publicRead then "ObjectWriter" else null;
      description = "S3 object ownership setting (defaults to ObjectWriter when publicRead is true)";
    };

    website = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = config.publicRead;
        description = "Enable static website hosting (defaults to true when publicRead is true)";
      };

      indexDocument = lib.mkOption {
        type = lib.types.str;
        default = "index.html";
        description = "Index document";
      };

      errorDocument = lib.mkOption {
        type = lib.types.str;
        default = "index.html";
        description = "Error document";
      };
    };

    cloudfrontAccess = lib.mkOption {
      type = lib.types.nullOr (lib.types.submodule {
        options = {
          distributionArn = lib.mkOption {
            type = lib.types.str;
            description = "CloudFront distribution ARN allowed to read objects";
          };
        };
      });
      default = null;
      description = "Allow CloudFront distribution access to the bucket";
    };

    nixBuild = lib.mkOption {
      type = lib.types.nullOr (lib.types.submodule (import ./nixBuild.nix));
      default = null;
      description = "Nix build configuration for uploading artifacts (deprecated, use nixBuilds)";
    };

    nixBuilds = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule (import ./nixBuild.nix));
      default = { };
      description = "Named Nix build configurations for uploading artifacts";
    };

    tags = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Tags for the bucket";
    };
  };
}
