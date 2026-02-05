{ lib, ... }:

{
  options = {
    authType = lib.mkOption {
      type = lib.types.str;
      default = "NONE";
      description = "Lambda Function URL auth type";
    };

    cors = lib.mkOption {
      type = lib.types.nullOr (lib.types.submodule {
        options = {
          allowOrigins = lib.mkOption {
            type = lib.types.nullOr (lib.types.listOf lib.types.str);
            default = null;
          };

          allowMethods = lib.mkOption {
            type = lib.types.nullOr (lib.types.listOf lib.types.str);
            default = null;
          };

          allowHeaders = lib.mkOption {
            type = lib.types.nullOr (lib.types.listOf lib.types.str);
            default = null;
          };

          exposeHeaders = lib.mkOption {
            type = lib.types.nullOr (lib.types.listOf lib.types.str);
            default = null;
          };

          allowCredentials = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
          };

          maxAge = lib.mkOption {
            type = lib.types.nullOr lib.types.int;
            default = null;
          };
        };
      });
      default = null;
      description = "CORS configuration for the function URL";
    };
  };
}
