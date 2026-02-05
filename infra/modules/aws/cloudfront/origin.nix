{ lib, ... }:

{
  options = {
    domainName = lib.mkOption {
      type = lib.types.str;
      description = "Origin domain name";
    };

    originId = lib.mkOption {
      type = lib.types.str;
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

    httpPort = lib.mkOption {
      type = lib.types.int;
      default = 80;
      description = "HTTP port";
    };

    httpsPort = lib.mkOption {
      type = lib.types.int;
      default = 443;
      description = "HTTPS port";
    };
  };
}
