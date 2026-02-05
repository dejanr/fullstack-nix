{ lib, ... }:

{
  options = {
    pathPattern = lib.mkOption {
      type = lib.types.str;
      description = "Path pattern for the cache behavior";
    };

    targetOriginId = lib.mkOption {
      type = lib.types.str;
      description = "Origin ID for this behavior";
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

    queryString = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Forward query string";
    };

    cookiesForward = lib.mkOption {
      type = lib.types.str;
      default = "none";
      description = "Cookies forward setting";
    };

    cachePolicyId = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Cache policy ID (use AWS managed policies like CachingDisabled)";
    };

    originRequestPolicyId = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Origin request policy ID";
    };
  };
}
