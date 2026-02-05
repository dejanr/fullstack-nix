{ lib }:

let
  sanitizeName = name: builtins.replaceStrings [ "-" "." ] [ "_" "_" ] name;
  mkRef =
    type: name: attr:
    "\${${type}.${sanitizeName name}.${attr}}";
  mkDataRef =
    type: name: attr:
    "\${data.${type}.${sanitizeName name}.${attr}}";

  mkLambdaRef = name: {
    arn = mkRef "aws_lambda_function" name "arn";
    invokeArn = mkRef "aws_lambda_function" name "invoke_arn";
    functionUrl = mkRef "aws_lambda_function_url" "${name}_url" "function_url";
    functionUrlDomain = "\${trimsuffix(replace(aws_lambda_function_url.${sanitizeName name}_url.function_url, \"https://\", \"\"), \"/\")}";
  };

  mkS3Ref = name: {
    bucket = mkRef "aws_s3_bucket" name "bucket";
    arn = mkRef "aws_s3_bucket" name "arn";
    domainName = mkRef "aws_s3_bucket" name "bucket_regional_domain_name";
    websiteEndpoint = mkRef "aws_s3_bucket_website_configuration" "${name}_website" "website_endpoint";
  };

  mkAcmRef = name: {
    arn = mkRef "aws_acm_certificate" name "arn";
    domainValidationOptions = mkRef "aws_acm_certificate" name "domain_validation_options";
  };

  mkSecretRef = name: {
    arn = mkRef "aws_secretsmanager_secret" name "arn";
    value = mkDataRef "aws_secretsmanager_secret_version" name "secret_string";
  };

  mkIamRoleRef = name: {
    arn = mkRef "aws_iam_role" name "arn";
    name = mkRef "aws_iam_role" name "name";
  };

  # Dynamic attribute set that generates refs on access
  mkDynamicRefs = mkFn: lib.mapAttrs (name: _: mkFn name);
in
config: {
  # Dynamic refs: infra.lambda.frontend, infra.lambda.backend-example, etc.
  # Automatically available for any defined resource
  lambda = mkDynamicRefs mkLambdaRef config.aws.lambda;
  s3 = mkDynamicRefs mkS3Ref config.aws.s3;
  acm = mkDynamicRefs mkAcmRef config.aws.acm;

  # Function-based refs (for resources not in config)
  secret = mkSecretRef;
  iam.role = mkIamRoleRef;

  cloudfront = {
    cachePolicy = name: {
      id = mkRef "aws_cloudfront_cache_policy" name "id";
    };
    cachePolicies = {
      cachingDisabled = {
        id = mkDataRef "aws_cloudfront_cache_policy" "caching_disabled" "id";
      };
      cachingOptimized = {
        id = mkDataRef "aws_cloudfront_cache_policy" "caching_optimized" "id";
      };
    };
    originRequestPolicy = name: {
      id = mkRef "aws_cloudfront_origin_request_policy" name "id";
    };
  };

  callerIdentity = {
    accountId = "\${data.aws_caller_identity.current.account_id}";
    arn = "\${data.aws_caller_identity.current.arn}";
  };
}
