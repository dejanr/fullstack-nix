{ lib, config, ... }:

let
  cfg = config.aws;
  sanitizeName = name: builtins.replaceStrings [ "-" "." ] [ "_" "_" ] name;
  functions = cfg.lambda;
  functionsWithManagedRole = lib.filterAttrs (_: function: function.roleArn == null) functions;
  # Normalize nixBuild string to attrset
  normalizeNixBuild = nixBuild:
    if builtins.isString nixBuild then { flake = nixBuild; outputPath = "lambda.zip"; }
    else nixBuild;
  
  functionsWithNixBuild = lib.filterAttrs (_: function: function.nixBuild != null) functions;
  functionsWithFunctionUrl = lib.filterAttrs (_: function: function.functionUrl != null) functions;
  functionsWithPublicUrl = lib.filterAttrs (
    _: function: function.functionUrl != null && function.functionUrl.authType == "NONE"
  ) functions;
  
  functionsWithPolicies = lib.filterAttrs (
    _: function: function.roleArn == null && function.policies != []
  ) functions;
  
  # Parse flake reference "dir#output" into { sourceDir, flakeOutput }
  # dir is relative to project root, terraform runs from infra/config/terraform/<env>/
  parseFlake = flake:
    let
      parts = lib.splitString "#" flake;
      dir = builtins.elemAt parts 0;
      output = if builtins.length parts > 1 then builtins.elemAt parts 1 else "default";
    in {
      sourceDir = "\${path.root}/../../../../${dir}";
      flakeOutput = ".#${output}";
    };
in
{
  options.aws = {
    lambda = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule (import ./function.nix));
      description = "Lambda functions to deploy (keyed by logical name)";
      default = { };
    };

    lambdaTags = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      description = "Tags to apply to all Lambda functions";
      default = { };
    };
  };

  config = lib.mkIf (functions != { }) {
    data.external = lib.mapAttrs' (
      name: function:
      let
        resourceName = sanitizeName name;
        nixBuild = normalizeNixBuild function.nixBuild;
        parsed = parseFlake nixBuild.flake;
      in
      lib.nameValuePair "${resourceName}_lambda_build_hash" {
        program = [
          "bash"
          "-c"
          ''
            set -e
            cd ${parsed.sourceDir}
            STORE_PATH=$(nix build ${parsed.flakeOutput} --print-out-paths --no-link --no-eval-cache)
            ARCHIVE_PATH="$STORE_PATH/${nixBuild.outputPath}"
            HASH=$(basename "$STORE_PATH" | cut -d'-' -f1)
            SOURCE_CODE_HASH=$(nix hash file --type sha256 --base64 "$ARCHIVE_PATH")
            echo "{\"hash\": \"$HASH\", \"archive_path\": \"$ARCHIVE_PATH\", \"source_code_hash\": \"$SOURCE_CODE_HASH\"}"
          ''
        ];
      }
    ) functionsWithNixBuild;

    resource.aws_iam_role = lib.mapAttrs' (
      name: function:
      let
        resourceName = sanitizeName name;
      in
      lib.nameValuePair "${resourceName}_role" {
        name = "${function.name}-role";
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
      }
    ) functionsWithManagedRole;

    resource.aws_lambda_function_url = lib.mapAttrs' (
      name: function:
      let
        resourceName = sanitizeName name;
        corsConfig = function.functionUrl.cors;
      in
      lib.nameValuePair "${resourceName}_url" (
        {
          function_name = "\${aws_lambda_function.${resourceName}.function_name}";
          authorization_type = function.functionUrl.authType;
        }
        // lib.optionalAttrs (corsConfig != null) {
          cors = lib.filterAttrs (_: value: value != null) {
            allow_origins = corsConfig.allowOrigins;
            allow_methods = corsConfig.allowMethods;
            allow_headers = corsConfig.allowHeaders;
            expose_headers = corsConfig.exposeHeaders;
            allow_credentials = corsConfig.allowCredentials;
            max_age = corsConfig.maxAge;
          };
        }
      )
    ) functionsWithFunctionUrl;

    resource.aws_lambda_permission =
      (lib.mapAttrs' (
        name: function:
        let
          resourceName = sanitizeName name;
        in
        lib.nameValuePair "${resourceName}_url_public" {
          statement_id = "AllowPublicFunctionUrl${resourceName}";
          action = "lambda:InvokeFunctionUrl";
          function_name = "\${aws_lambda_function.${resourceName}.function_name}";
          principal = "*";
          function_url_auth_type = "NONE";
        }
      ) functionsWithPublicUrl)
      // (lib.mapAttrs' (
        name: function:
        let
          resourceName = sanitizeName name;
        in
        lib.nameValuePair "${resourceName}_invoke" {
          statement_id = "AllowInvoke${resourceName}";
          action = "lambda:InvokeFunction";
          function_name = "\${aws_lambda_function.${resourceName}.function_name}";
          principal = "*";
        }
      ) functionsWithPublicUrl);

    resource.aws_iam_role_policy_attachment = 
      # Basic execution policy
      (lib.mapAttrs' (
        name: _: 
        let
          resourceName = sanitizeName name;
        in
        lib.nameValuePair "${resourceName}_basic_policy" {
          role = "\${aws_iam_role.${resourceName}_role.name}";
          policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole";
        }
      ) functionsWithManagedRole)
      # Custom policies
      // (lib.mapAttrs' (
        name: _:
        let
          resourceName = sanitizeName name;
        in
        lib.nameValuePair "${resourceName}_custom_policy" {
          role = "\${aws_iam_role.${resourceName}_role.name}";
          policy_arn = "\${aws_iam_policy.${resourceName}_policy.arn}";
        }
      ) functionsWithPolicies);

    # Custom policies for lambdas
    resource.aws_iam_policy = lib.mapAttrs' (
      name: function:
      let
        resourceName = sanitizeName name;
      in
      lib.nameValuePair "${resourceName}_policy" {
        name = "\${var.project_name}-${name}-policy";
        policy = builtins.toJSON {
          Version = "2012-10-17";
          Statement = map (stmt: {
            Effect = "Allow";
            Action = stmt.actions;
            Resource = stmt.resources;
          }) function.policies;
        };
      }
    ) functionsWithPolicies;

    resource.aws_lambda_function = lib.mapAttrs' (
      name: function:
      let
        resourceName = sanitizeName name;
        archiveName = "${resourceName}.zip";
        roleArn =
          if function.roleArn != null then
            function.roleArn
          else
            "\${aws_iam_role.${resourceName}_role.arn}";
        lambdaFilename =
          if function.nixBuild != null then
            "\${data.external.${resourceName}_lambda_build_hash.result.archive_path}"
          else
            function.filename;
      in
      lib.nameValuePair resourceName (
        {
          function_name = function.name;
          description = function.description;
          handler = function.handler;
          runtime = function.runtime;
          filename = lambdaFilename;
          role = roleArn;
          timeout = function.timeout;
          memory_size = function.memorySize;
          publish = function.publish;
          source_code_hash =
            if function.nixBuild != null then
              "\${data.external.${resourceName}_lambda_build_hash.result.source_code_hash}"
            else
              "\${filebase64sha256(\"${lambdaFilename}\")}";
          tags = cfg.lambdaTags // function.tags;
        }
        // lib.optionalAttrs (function.environment != { }) {
          environment = {
            variables = function.environment;
          };
        }
      )
    ) functions;

    output.lambda_function_names = {
      description = "Lambda function names";
      value = lib.mapAttrs (
        name: _: "\${aws_lambda_function.${sanitizeName name}.function_name}"
      ) functions;
    };

    output.lambda_function_arns = {
      description = "Lambda function ARNs";
      value = lib.mapAttrs (
        name: _: "\${aws_lambda_function.${sanitizeName name}.arn}"
      ) functions;
    };

    output.lambda_function_urls = {
      description = "Lambda function URLs";
      value = lib.mapAttrs (
        name: _: "\${aws_lambda_function_url.${sanitizeName name}_url.function_url}"
      ) functionsWithFunctionUrl;
    };
  };
}
