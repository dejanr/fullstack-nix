{ lib, ... }:

{
  options = {
    flake = lib.mkOption {
      type = lib.types.str;
      description = "Flake reference as 'dir#output' (e.g., 'frontend#frontend'). Dir is relative to infra/config.";
    };

    outputPath = lib.mkOption {
      type = lib.types.str;
      default = ".";
      description = "Path within the Nix output to upload";
    };

    targetPrefix = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "S3 key prefix for uploaded files (e.g., 'static/' or empty for root)";
    };

    cacheControl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Cache-Control header to apply to all uploaded files";
    };
  };
}
