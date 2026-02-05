{ lib, config, ... }:

let
  cfg = config.aws;
  s3Buckets = cfg.s3 or { };
  needsCallerIdentity = lib.any (bucket: lib.hasInfix "aws_caller_identity" bucket.name) (
    lib.attrValues s3Buckets
  );

  defaultTags = {
    Project = "\${var.project_name}";
    Environment = "\${var.environment}";
  }
  // cfg.tags;
in
{
  imports = [
    ./aws/s3
    ./aws/cloudfront
    ./aws/lambda
    ./aws/acm
    ./aws/iam
    ./aws/secretsmanager
    ./cloudflare
  ];

  options.infra = lib.mkOption {
    type = lib.types.attrs;
    default = (import ./aws/refs.nix { inherit lib; }) config;
    readOnly = true;
    description = "Helper references for cross-module dependencies";
  };

  options.aws.tags = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = { };
    description = "Global tags applied to all AWS resources";
  };

  config = lib.mkMerge [
    (lib.mkIf needsCallerIdentity {
      data.aws_caller_identity.current = { };
    })

    # Set default tags for all modules
    {
      aws.s3Tags = defaultTags;
      aws.lambdaTags = defaultTags;
      aws.acmTags = defaultTags;
      aws.cloudfrontTags = defaultTags;
      aws.secretsmanager.tags = lib.mkDefault defaultTags;
      aws.iam.tags = lib.mkDefault defaultTags;
    }
  ];
}
