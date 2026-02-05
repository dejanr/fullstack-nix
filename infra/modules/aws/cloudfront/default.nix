{ lib, config, ... }:

let
  cfg = config.aws.cloudfront;
  sanitizeName = name: builtins.replaceStrings [ "-" "." ] [ "_" "_" ] name;

  # Cache policies - CloudFront respects origin Cache-Control headers with CachingOptimized
  cachePolicies = {
    enabled = "\${data.aws_cloudfront_cache_policy.caching_optimized.id}";
    disabled = "\${data.aws_cloudfront_cache_policy.caching_disabled.id}";
  };

  # Check if any distribution uses lambda origins (need origin request policy)
  needsLambdaPolicy = lib.any (dist:
    lib.any (origin: origin.lambda != null) (lib.attrValues dist.origins)
  ) (lib.attrValues cfg);

  # Managed cache policies
  managedCachePolicies = {
    caching_disabled = "Managed-CachingDisabled";
    caching_optimized = "Managed-CachingOptimized";
  };

  hasDistributions = cfg != { };
in
{
  options.aws.cloudfrontTags = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = { };
    description = "Tags to apply to all CloudFront distributions";
  };

  options.aws.cloudfront = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
      options = {
        aliases = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Domain aliases";
        };

        certificate = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "ACM certificate name (references aws.acm.<name>)";
        };

        defaultRootObject = lib.mkOption {
          type = lib.types.str;
          default = "index.html";
          description = "Default root object";
        };

        origins = lib.mkOption {
          type = lib.types.attrsOf (lib.types.submodule {
            options = {
              s3 = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "S3 bucket name (references aws.s3.<name>)";
              };
              s3Path = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "S3 origin path prefix (e.g., '/client')";
              };
              lambda = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Lambda function name (references aws.lambda.<name>)";
              };
            };
          });
          description = "Origins (s3 or lambda by name)";
        };

        routes = lib.mkOption {
          type = lib.types.attrsOf (lib.types.submodule {
            options = {
              origin = lib.mkOption {
                type = lib.types.str;
                description = "Origin name to route to";
              };
              cache = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Enable caching (uses origin Cache-Control headers)";
              };
            };
          });
          default = { };
          description = "Path pattern routes";
        };

        tags = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          description = "Tags";
        };
      };
    }));
    default = { };
    description = "CloudFront distributions";
  };

  config = lib.mkIf hasDistributions {
    # Managed cache policy data sources
    data.aws_cloudfront_cache_policy = lib.mapAttrs (name: policyName: {
      name = policyName;
    }) managedCachePolicies;



    # Lambda origin request policy (forwards cookies, query strings)
    resource.aws_cloudfront_origin_request_policy = lib.mkIf needsLambdaPolicy {
      lambda = {
        name = "\${var.project_name}-\${var.environment}-lambda-origin-request";
        headers_config = {
          header_behavior = "allExcept";
          headers = { items = [ "Host" ]; };
        };
        cookies_config = { cookie_behavior = "all"; };
        query_strings_config = { query_string_behavior = "all"; };
      };
    };

    resource.aws_cloudfront_distribution = lib.mapAttrs' (name: dist:
      let
        resourceName = sanitizeName name;

        # Get first origin as default
        defaultOriginName = builtins.head (lib.attrNames dist.origins);
        defaultOrigin = dist.origins.${defaultOriginName};

        # Build origin configs - resolve names to terraform refs
        mkOrigin = originName: origin:
          let
            isS3 = origin.s3 != null;
            domainName = if isS3
              then "\${aws_s3_bucket_website_configuration.${sanitizeName origin.s3}_website.website_endpoint}"
              else "\${trimsuffix(replace(aws_lambda_function_url.${sanitizeName origin.lambda}_url.function_url, \"https://\", \"\"), \"/\")}";
          in {
            domain_name = domainName;
            origin_id = originName;
            custom_origin_config = {
              http_port = 80;
              https_port = 443;
              origin_protocol_policy = if isS3 then "http-only" else "https-only";
              origin_ssl_protocols = [ "TLSv1.2" ];
            };
          } // lib.optionalAttrs (origin.s3Path != null) {
            origin_path = origin.s3Path;
          };

        # Build route behaviors - sort by specificity (longer/more specific patterns first)
        # CloudFront evaluates in order, first match wins
        routesList = lib.filterAttrs (path: _: path != "/") dist.routes;
        sortedRoutes = lib.sort (a: b:
          let
            # Patterns without wildcards are more specific
            aHasWildcard = lib.hasInfix "*" a.name;
            bHasWildcard = lib.hasInfix "*" b.name;
            # Longer patterns are more specific (when both have or don't have wildcards)
            aLen = lib.stringLength a.name;
            bLen = lib.stringLength b.name;
          in
          if aHasWildcard != bHasWildcard then !aHasWildcard
          else if a.name == "/*" then false  # /* always last
          else if b.name == "/*" then true
          else aLen > bLen
        ) (lib.mapAttrsToList (name: value: { inherit name value; }) routesList);
        defaultRoute = dist.routes."/" or { origin = defaultOriginName; cache = false; };

        mkBehaviorFromSorted = item:
          let
            path = item.name;
            route = item.value;
            origin = dist.origins.${route.origin};
            isLambda = origin.lambda != null;
            cachePolicyId = if route.cache then cachePolicies.enabled else cachePolicies.disabled;
          in {
            path_pattern = path;
            target_origin_id = route.origin;
            viewer_protocol_policy = "redirect-to-https";
            allowed_methods = if isLambda then [ "GET" "HEAD" "OPTIONS" "PUT" "POST" "PATCH" "DELETE" ] else [ "GET" "HEAD" ];
            cached_methods = [ "GET" "HEAD" ];
            compress = true;
            cache_policy_id = cachePolicyId;
          } // lib.optionalAttrs isLambda {
            origin_request_policy_id = "\${aws_cloudfront_origin_request_policy.lambda.id}";
          };

        defaultOriginConfig = dist.origins.${defaultRoute.origin};
        defaultIsLambda = defaultOriginConfig.lambda != null;
        defaultCachePolicyId = if defaultRoute.cache then cachePolicies.enabled else cachePolicies.disabled;
      in
      lib.nameValuePair resourceName {
        enabled = true;
        comment = "${name} distribution";
        aliases = dist.aliases;
        default_root_object = dist.defaultRootObject;
        price_class = "PriceClass_100";
        is_ipv6_enabled = true;

        origin = lib.mapAttrsToList mkOrigin dist.origins;

        default_cache_behavior = {
          target_origin_id = defaultRoute.origin;
          viewer_protocol_policy = "redirect-to-https";
          allowed_methods = if defaultIsLambda then [ "GET" "HEAD" "OPTIONS" "PUT" "POST" "PATCH" "DELETE" ] else [ "GET" "HEAD" ];
          cached_methods = [ "GET" "HEAD" ];
          compress = true;
          cache_policy_id = defaultCachePolicyId;
        } // lib.optionalAttrs defaultIsLambda {
          origin_request_policy_id = "\${aws_cloudfront_origin_request_policy.lambda.id}";
        };

        ordered_cache_behavior = map mkBehaviorFromSorted sortedRoutes;

        restrictions = {
          geo_restriction = { restriction_type = "none"; };
        };

        viewer_certificate = if dist.certificate != null then {
          acm_certificate_arn = "\${aws_acm_certificate.${sanitizeName dist.certificate}.arn}";
          ssl_support_method = "sni-only";
          minimum_protocol_version = "TLSv1.2_2021";
        } else {
          cloudfront_default_certificate = true;
          minimum_protocol_version = "TLSv1.2_2021";
        };

        tags = config.aws.cloudfrontTags // dist.tags;
      } // lib.optionalAttrs (dist.certificate != null) {
        depends_on = [ "aws_acm_certificate_validation.${sanitizeName dist.certificate}_validation" ];
      }
    ) cfg;

    output.cloudfront_domain_names = {
      description = "CloudFront distribution domain names";
      value = lib.mapAttrs (name: _:
        "\${aws_cloudfront_distribution.${sanitizeName name}.domain_name}"
      ) cfg;
    };

    output.cloudfront_hosted_zone_ids = {
      description = "CloudFront hosted zone IDs";
      value = lib.mapAttrs (name: _:
        "\${aws_cloudfront_distribution.${sanitizeName name}.hosted_zone_id}"
      ) cfg;
    };
  };
}
