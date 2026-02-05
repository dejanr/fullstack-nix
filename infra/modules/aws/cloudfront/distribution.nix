{ lib, ... }:

{
  options = {
    enabled = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to create the distribution";
    };

    comment = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Distribution comment";
    };

    aliases = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Alternate domain names (CNAMEs)";
    };

    defaultRootObject = lib.mkOption {
      type = lib.types.str;
      default = "index.html";
      description = "Default root object";
    };

    originDomainName = lib.mkOption {
      type = lib.types.str;
      description = "Origin domain name";
    };

    originId = lib.mkOption {
      type = lib.types.str;
      default = "origin";
      description = "Origin ID";
    };

    originProtocolPolicy = lib.mkOption {
      type = lib.types.str;
      default = "https-only";
      description = "Origin protocol policy";
    };

    originSslProtocols = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "TLSv1.2" ];
      description = "Allowed SSL protocols for the origin";
    };

    extraOrigins = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule (import ./origin.nix));
      default = { };
      description = "Additional origins for the distribution";
    };

    orderedCacheBehaviors = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule (import ./cacheBehavior.nix));
      default = [ ];
      description = "Ordered cache behaviors";
    };

    priceClass = lib.mkOption {
      type = lib.types.str;
      default = "PriceClass_100";
      description = "CloudFront price class";
    };

    viewerProtocolPolicy = lib.mkOption {
      type = lib.types.str;
      default = "redirect-to-https";
      description = "Viewer protocol policy";
    };

    allowedMethods = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "GET" "HEAD" "OPTIONS" ];
      description = "Allowed HTTP methods";
    };

    cachedMethods = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "GET" "HEAD" ];
      description = "Cached HTTP methods";
    };

    compress = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable compression";
    };

    acmCertificateArn = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "ACM certificate ARN for custom domains";
    };

    sslSupportMethod = lib.mkOption {
      type = lib.types.str;
      default = "sni-only";
      description = "SSL support method";
    };

    minimumProtocolVersion = lib.mkOption {
      type = lib.types.str;
      default = "TLSv1.2_2021";
      description = "Minimum TLS protocol version";
    };

    cacheControl = lib.mkOption {
      type = lib.types.nullOr (lib.types.submodule {
        options = {
          maxAge = lib.mkOption {
            type = lib.types.int;
            description = "Max-age in seconds";
          };

          staleWhileRevalidate = lib.mkOption {
            type = lib.types.nullOr lib.types.int;
            default = null;
            description = "Stale-while-revalidate in seconds";
          };

          staleIfError = lib.mkOption {
            type = lib.types.nullOr lib.types.int;
            default = null;
            description = "Stale-if-error in seconds";
          };
        };
      });
      default = null;
      description = "Cache-Control response header policy";
    };

    defaultCachePolicyId = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Cache policy ID for default behavior (uses forwarded_values if null)";
    };

    defaultOriginRequestPolicyId = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Origin request policy ID for default behavior";
    };

    tags = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Tags for the distribution";
    };
  };
}
