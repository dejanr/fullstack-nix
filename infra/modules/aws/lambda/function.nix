{ lib, name, ... }:

{
  options = {
    name = lib.mkOption {
      type = lib.types.str;
      default = "\${var.project_name}-${name}";
      description = "Lambda function name (defaults to project_name-key)";
    };

    description = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Lambda description";
    };

    handler = lib.mkOption {
      type = lib.types.str;
      default = "index.handler";
      description = "Handler entrypoint";
    };

    runtime = lib.mkOption {
      type = lib.types.str;
      default = "nodejs20.x";
      description = "Lambda runtime";
    };

    filename = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Path to the deployment package zip";
    };

    nixBuild = lib.mkOption {
      type = lib.types.nullOr (lib.types.either lib.types.str (lib.types.submodule (import ./nixBuild.nix)));
      default = null;
      description = "Nix build: either a flake string 'dir#output' or { flake, outputPath }";
    };

    timeout = lib.mkOption {
      type = lib.types.int;
      default = 15;
      description = "Timeout in seconds";
    };

    memorySize = lib.mkOption {
      type = lib.types.int;
      default = 256;
      description = "Memory size in MB";
    };

    roleArn = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "IAM role ARN to use instead of creating a new role";
    };

    policies = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          actions = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "IAM actions (e.g., s3:GetObject)";
          };
          resources = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "Resource ARNs";
          };
        };
      });
      default = [ ];
      description = "IAM policy statements for the lambda role";
    };

    publish = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Publish a new function version";
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Environment variables";
    };

    functionUrl = lib.mkOption {
      type = lib.types.nullOr (lib.types.submodule (import ./functionUrl.nix));
      default = null;
      description = "Lambda Function URL configuration";
    };

    tags = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Tags for the function";
    };
  };
}
