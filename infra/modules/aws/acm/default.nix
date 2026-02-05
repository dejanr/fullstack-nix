{ lib, config, ... }:

let
  cfg = config.aws;
  sanitizeName = name: builtins.replaceStrings [ "-" "." ] [ "_" "_" ] name;
  
  # Normalize string to { domainName = "..."; }
  normalizeCert = cert: 
    if builtins.isString cert 
    then { domainName = cert; subjectAlternativeNames = []; validationMethod = "DNS"; tags = {}; }
    else cert;
  
  certificates = lib.mapAttrs (_: normalizeCert) cfg.acm;
  providerRef = "aws.us_east_1";
  
  # Check if Cloudflare is managing DNS (for automatic validation)
  cloudflareEnabled = config.cloudflare.enable or false;
in
{
  options.aws = {
    acm = lib.mkOption {
      type = lib.types.attrsOf (lib.types.either
        lib.types.str
        (lib.types.submodule (import ./certificate.nix))
      );
      description = "ACM certificates (keyed by logical name). Can be string (domain) or attrset.";
      default = { };
    };

    acmTags = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      description = "Tags to apply to all ACM certificates";
      default = { };
    };
  };

  config = lib.mkIf (certificates != { }) {
    resource.aws_acm_certificate = lib.mapAttrs' (
      name: certificate:
      let
        resourceName = sanitizeName name;
      in
      lib.nameValuePair resourceName {
        provider = providerRef;
        domain_name = certificate.domainName;
        subject_alternative_names = certificate.subjectAlternativeNames;
        validation_method = certificate.validationMethod;
        tags = cfg.acmTags // certificate.tags;
        lifecycle = {
          create_before_destroy = true;
        };
      }
    ) certificates;

    # Create validation resources that wait for DNS records
    # Depends on Cloudflare records when Cloudflare is enabled
    resource.aws_acm_certificate_validation = lib.mkIf cloudflareEnabled (lib.mapAttrs' (
      name: certificate:
      let
        resourceName = sanitizeName name;
      in
      lib.nameValuePair "${resourceName}_validation" {
        provider = providerRef;
        certificate_arn = "\${aws_acm_certificate.${resourceName}.arn}";
        depends_on = [ "cloudflare_record.acm_${resourceName}" ];
      }
    ) certificates);

    output.acm_certificate_arns = {
      description = "ACM certificate ARNs";
      value = lib.mapAttrs (
        name: _: "\${aws_acm_certificate.${sanitizeName name}.arn}"
      ) certificates;
    };

    output.acm_certificate_validation_options = {
      description = "ACM validation options";
      value = lib.mapAttrs (
        name: _: "\${aws_acm_certificate.${sanitizeName name}.domain_validation_options}"
      ) certificates;
    };
  };
}
