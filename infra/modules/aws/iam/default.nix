{ lib, config, ... }:

let
  cfg = config.aws.iam;
  sanitizeName = name: builtins.replaceStrings [ "-" "." ] [ "_" "_" ] name;

  statementToJson = statement:
    {
      Effect = statement.effect;
      Action = statement.actions;
      Resource = statement.resources;
    }
    // lib.optionalAttrs (statement.conditions != { }) {
      Condition = statement.conditions;
    };

  policyDocument = statements:
    builtins.toJSON {
      Version = "2012-10-17";
      Statement = map statementToJson statements;
    };

  lambdaRoles = cfg.lambdaRoles;
  githubRoles = cfg.githubOidc.roles;
  oidcEnabled = cfg.githubOidc.enable;
  providerUrl = cfg.githubOidc.providerUrl;
  providerArn = "\${data.aws_iam_openid_connect_provider.github.arn}";

  lambdaRolesWithPolicies = lib.filterAttrs (
    _: role: role.policyStatements != [ ]
  ) lambdaRoles;
  githubRolesWithPolicies = lib.filterAttrs (
    _: role: role.policyStatements != [ ]
  ) githubRoles;
  basicLambdaAttachments = lib.mapAttrs' (
    name: role:
    let
      resourceName = sanitizeName name;
    in
    lib.nameValuePair "${resourceName}_basic_execution" {
      role = "\${aws_iam_role.${resourceName}.name}";
      policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole";
    }
  ) (lib.filterAttrs (_: role: role.attachBasicExecution) lambdaRoles);
in
{
  options.aws.iam = {
    lambdaRoles = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule (import ./lambdaRole.nix));
      description = "IAM roles for Lambda functions";
      default = { };
    };

    githubOidc = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable GitHub OIDC provider and roles";
      };

      providerUrl = lib.mkOption {
        type = lib.types.str;
        default = "https://token.actions.githubusercontent.com";
        description = "OIDC provider URL";
      };

      clientIds = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "sts.amazonaws.com" ];
        description = "OIDC client IDs";
      };

      thumbprints = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "6938fd4d98bab03faadb97b34396831e3780aea1" ];
        description = "OIDC thumbprints (AWS ignores this for GitHub OIDC but requires a non-empty value)";
      };

      roles = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule (import ./githubOidcRole.nix));
        description = "GitHub OIDC roles";
        default = { };
      };
    };

    tags = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      description = "Tags to apply to IAM resources";
      default = { };
    };
  };

  config = {
    resource.aws_iam_role =
      (lib.mapAttrs' (
        name: role:
        let
          resourceName = sanitizeName name;
        in
        lib.nameValuePair resourceName {
          name = role.name;
          assume_role_policy = builtins.toJSON {
            Version = "2012-10-17";
            Statement = [
              {
                Effect = "Allow";
                Action = "sts:AssumeRole";
                Principal = {
                  Service = "lambda.amazonaws.com";
                };
              }
            ];
          };
          tags = cfg.tags // role.tags;
        }
      ) lambdaRoles)
      // (lib.mapAttrs' (
        name: role:
        let
          resourceName = sanitizeName name;
        in
        lib.nameValuePair "github_${resourceName}" {
          name = role.name;
          assume_role_policy = builtins.toJSON {
            Version = "2012-10-17";
            Statement = [
              {
                Effect = "Allow";
                Action = "sts:AssumeRoleWithWebIdentity";
                Principal = {
                  Federated = providerArn;
                };
                Condition = {
                  StringEquals = {
                    "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com";
                  };
                  StringLike = {
                    "token.actions.githubusercontent.com:sub" = role.subjects;
                  };
                };
              }
            ];
          };
          tags = cfg.tags // role.tags;
        }
      ) githubRoles);

    resource.aws_iam_policy =
      (lib.mapAttrs' (
        name: role:
        let
          resourceName = sanitizeName name;
        in
        lib.nameValuePair "${resourceName}_policy" {
          name = "${role.name}-policy";
          policy = policyDocument role.policyStatements;
          tags = cfg.tags // role.tags;
        }
      ) lambdaRolesWithPolicies)
      // (lib.mapAttrs' (
        name: role:
        let
          resourceName = sanitizeName name;
        in
        lib.nameValuePair "github_${resourceName}_policy" {
          name = "${role.name}-policy";
          policy = policyDocument role.policyStatements;
          tags = cfg.tags // role.tags;
        }
      ) githubRolesWithPolicies);

    resource.aws_iam_role_policy_attachment =
      basicLambdaAttachments
      // (lib.mapAttrs' (
        name: role:
        let
          resourceName = sanitizeName name;
        in
        lib.nameValuePair "${resourceName}_policy_attach" {
          role = "\${aws_iam_role.${resourceName}.name}";
          policy_arn = "\${aws_iam_policy.${resourceName}_policy.arn}";
        }
      ) lambdaRolesWithPolicies)
      // (lib.mapAttrs' (
        name: role:
        let
          resourceName = sanitizeName name;
        in
        lib.nameValuePair "github_${resourceName}_policy_attach" {
          role = "\${aws_iam_role.github_${resourceName}.name}";
          policy_arn = "\${aws_iam_policy.github_${resourceName}_policy.arn}";
        }
      ) githubRolesWithPolicies);

    # Use existing GitHub OIDC provider (there's only one per AWS account)
    data.aws_iam_openid_connect_provider = lib.mkIf oidcEnabled {
      github = {
        url = providerUrl;
      };
    };

    output.lambda_role_arns = {
      description = "Lambda role ARNs";
      value = lib.mapAttrs (
        name: _:
        let
          resourceName = sanitizeName name;
        in
        "\${aws_iam_role.${resourceName}.arn}"
      ) lambdaRoles;
    };

    output.github_oidc_role_arns = lib.mkIf (githubRoles != { }) {
      description = "GitHub OIDC role ARNs";
      value = lib.mapAttrs (
        name: _:
        let
          resourceName = sanitizeName name;
        in
        "\${aws_iam_role.github_${resourceName}.arn}"
      ) githubRoles;
    };

    output.github_oidc_provider_arn = lib.mkIf oidcEnabled {
      description = "GitHub OIDC provider ARN";
      value = "\${data.aws_iam_openid_connect_provider.github.arn}";
    };
  };
}
