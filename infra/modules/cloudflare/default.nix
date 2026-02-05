{ lib, config, ... }:

let
  cfg = config.cloudflare;
  sanitizeName = name: builtins.replaceStrings [ "-" "." "@" "*" ] [ "_" "_" "_" "wildcard_" ] name;

  findZoneId =
    domain:
    let
      matchingZones = lib.filterAttrs (zone: _: lib.hasSuffix zone domain) cfg.zones;
      sortedZones = lib.sort (a: b: lib.stringLength a > lib.stringLength b) (
        lib.attrNames matchingZones
      );
    in
    if sortedZones == [ ] then cfg.defaultZoneId else cfg.zones.${builtins.head sortedZones};

  cloudfrontRecords = lib.flatten (
    lib.mapAttrsToList (
      name: dist:
      map (alias: {
        name = alias;
        value = {
          type = "CNAME";
          value = "\${aws_cloudfront_distribution.${sanitizeName name}.domain_name}";
          proxied = false;
          ttl = 1;
          zoneId = findZoneId alias;
        };
      }) dist.aliases
    ) config.aws.cloudfront
  );

  cloudfrontRecordsAttrs = lib.listToAttrs cloudfrontRecords;

  allRecords = cloudfrontRecordsAttrs // cfg.records;

  hasRecords = allRecords != { } || config.aws.acm != { };
in
{
  options.cloudflare = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Cloudflare DNS management (auto-generates CloudFront + ACM records)";
    };

    zones = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Map of domain -> zone ID (e.g., { \"example.com\" = \"abc123\"; })";
    };

    defaultZoneId = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Default zone ID for domains not matching any zone in 'zones'";
    };

    zoneId = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Deprecated: use 'zones' instead. Falls back to defaultZoneId.";
    };

    records = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule (
          { ... }:
          {
            options = {
              type = lib.mkOption {
                type = lib.types.enum [
                  "A"
                  "AAAA"
                  "CNAME"
                  "TXT"
                  "MX"
                  "NS"
                ];
                default = "CNAME";
                description = "DNS record type";
              };
              value = lib.mkOption {
                type = lib.types.str;
                description = "DNS record value";
              };
              proxied = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Enable Cloudflare proxy (orange cloud)";
              };
              ttl = lib.mkOption {
                type = lib.types.int;
                default = 1;
                description = "TTL in seconds (1 = auto)";
              };
              zoneId = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Override zone ID for this record";
              };
            };
          }
        )
      );
      default = { };
      description = "Additional DNS records (CloudFront aliases are auto-generated)";
    };
  };

  config = lib.mkIf (cfg.enable && hasRecords) {
    cloudflare.defaultZoneId = lib.mkDefault cfg.zoneId;
    terraform.required_providers.cloudflare = {
      source = "cloudflare/cloudflare";
      version = "~> 4.0";
    };
    provider.cloudflare = { };
    resource.cloudflare_record =
      lib.mapAttrs' (
        key: record:
        let
          zoneId = if record.zoneId or null != null then record.zoneId else findZoneId key;
        in
        lib.nameValuePair (sanitizeName key) {
          zone_id = zoneId;
          name = key;
          type = record.type;
          content = record.value;
          proxied = record.proxied;
          ttl = if record.proxied then 1 else record.ttl;
        }
      ) allRecords
      // lib.mapAttrs' (
        name: domain:
        let
          resourceName = sanitizeName name;
          zoneId = findZoneId domain;
        in
        lib.nameValuePair "acm_${resourceName}" {
          for_each = "\${{ for dvo in aws_acm_certificate.${resourceName}.domain_validation_options : dvo.domain_name => { name = dvo.resource_record_name, record = dvo.resource_record_value, type = dvo.resource_record_type } }}";
          zone_id = zoneId;
          name = "\${each.value.name}";
          type = "\${each.value.type}";
          content = "\${each.value.record}";
          ttl = 60;
          proxied = false;
        }
      ) config.aws.acm;
  };
}
