{ lib, ... }:

{
  options = {
    domainName = lib.mkOption {
      type = lib.types.str;
      description = "Primary domain name for the certificate";
    };

    subjectAlternativeNames = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Subject alternative names";
    };

    validationMethod = lib.mkOption {
      type = lib.types.str;
      default = "DNS";
      description = "Validation method";
    };

    tags = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Tags for the certificate";
    };
  };
}
