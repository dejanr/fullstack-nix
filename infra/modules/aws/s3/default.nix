{ lib, config, ... }:

let
  cfg = config.aws;
  sanitizeName = name: builtins.replaceStrings [ "-" "." ] [ "_" "_" ] name;
  buckets = cfg.s3;
  websiteBuckets = lib.filterAttrs (_: bucket: bucket.website.enable) buckets;
  publicBuckets = lib.filterAttrs (_: bucket: bucket.publicRead && bucket.publicPolicy) buckets;
  
  # Parse flake reference "dir#output" into { sourceDir, flakeOutput }
  # dir is relative to project root
  parseFlake = flake:
    let
      parts = lib.splitString "#" flake;
      dir = builtins.elemAt parts 0;
      output = if builtins.length parts > 1 then builtins.elemAt parts 1 else "default";
    in {
      sourceDir = "\${path.root}/../../../../${dir}";
      flakeOutput = ".#${output}";
    };
  
  # Normalize nixBuild to nixBuilds for backwards compatibility
  getNixBuilds = bucket: 
    if bucket.nixBuilds != {} then bucket.nixBuilds
    else if bucket.nixBuild != null then { default = bucket.nixBuild; }
    else {};
  
  bucketsWithNixBuilds = lib.filterAttrs (_: bucket: (getNixBuilds bucket) != {}) buckets;
  
  # Flatten all builds with bucket context for resource generation
  allBuilds = lib.flatten (lib.mapAttrsToList (bucketName: bucket:
    lib.mapAttrsToList (buildName: build: 
      let parsed = parseFlake build.flake;
      in {
        inherit bucketName bucket build buildName;
        inherit (parsed) sourceDir flakeOutput;
        resourceName = "${sanitizeName bucketName}_${sanitizeName buildName}";
      }
    ) (getNixBuilds bucket)
  ) bucketsWithNixBuilds);
in
{
  options.aws = {
    s3 = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule (import ./bucket.nix));
      description = "S3 buckets to create (keyed by logical name)";
      default = { };
    };

    s3Tags = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      description = "Tags to apply to all S3 resources";
      default = { };
    };
  };

  config = lib.mkIf (buckets != { }) {
    data.external = builtins.listToAttrs (map (item:
      lib.nameValuePair "${item.resourceName}_build_hash" {
        program = [
          "bash"
          "-c"
          ''
            set -e
            cd ${item.sourceDir}
            STORE_PATH=$(nix build ${item.flakeOutput} --print-out-paths --no-link --no-eval-cache)
            HASH=$(basename "$STORE_PATH" | cut -d'-' -f1)
            echo "{\"hash\": \"$HASH\"}"
          ''
        ];
      }
    ) allBuilds);

    resource.null_resource = builtins.listToAttrs (map (item:
      let
        cacheControlValue = if item.build.cacheControl != null then item.build.cacheControl else "";
        cacheControlEscaped = lib.escapeShellArg cacheControlValue;
      in
      lib.nameValuePair "bucket_build_${item.resourceName}" {
        triggers = {
          source_hash = "\${data.external.${item.resourceName}_build_hash.result.hash}";
        };

        provisioner = [
          {
            local-exec = {
              command = ''
                set -e
                cd ${lib.escapeShellArg item.sourceDir}
                STORE_PATH=$(nix build ${lib.escapeShellArg item.flakeOutput} --print-out-paths --no-link)
                ARTIFACT_PATH="$STORE_PATH/${lib.escapeShellArg item.build.outputPath}"
                ACL_ARGS=()
                if [ "${if item.bucket.publicRead then "true" else "false"}" = "true" ]; then
                  ACL_ARGS=(--acl public-read)
                fi
                
                aws s3 cp "$ARTIFACT_PATH" "s3://${item.bucket.name}/${item.build.targetPrefix}" \
                  --recursive \
                  ${if cacheControlValue != "" then "--cache-control ${cacheControlEscaped}" else ""} \
                  "$''${ACL_ARGS[@]}"
              '';
              interpreter = [
                "bash"
                "-c"
              ];
            };
          }
        ];

        depends_on = [
          "aws_s3_bucket.${sanitizeName item.bucketName}"
        ] ++ lib.optional (item.bucket.objectOwnership != null) 
          "aws_s3_bucket_ownership_controls.${sanitizeName item.bucketName}_ownership"
        ++ lib.optional item.bucket.publicRead
          "aws_s3_bucket_public_access_block.${sanitizeName item.bucketName}_public_access";
      }
    ) allBuilds);

    resource.aws_s3_bucket = lib.mapAttrs' (
      name: bucket:
      lib.nameValuePair (sanitizeName name) {
        bucket = bucket.name;
        force_destroy = bucket.forceDestroy;
        tags = cfg.s3Tags // bucket.tags;
      }
    ) buckets;

    resource.aws_s3_bucket_versioning = lib.mapAttrs' (
      name: bucket:
      let
        resourceName = sanitizeName name;
      in
      lib.nameValuePair "${resourceName}_versioning" {
        bucket = "\${aws_s3_bucket.${resourceName}.id}";
        versioning_configuration = {
          status = if bucket.versioning then "Enabled" else "Suspended";
        };
      }
    ) buckets;

    resource.aws_s3_bucket_ownership_controls = lib.mapAttrs' (
      name: bucket:
      let
        resourceName = sanitizeName name;
      in
      lib.nameValuePair "${resourceName}_ownership" {
        bucket = "\${aws_s3_bucket.${resourceName}.id}";
        rule = {
          object_ownership = bucket.objectOwnership;
        };
      }
    ) (lib.filterAttrs (_: bucket: bucket.objectOwnership != null) buckets);

    resource.aws_s3_bucket_public_access_block = lib.mapAttrs' (
      name: bucket:
      let
        resourceName = sanitizeName name;
        allowPublic = bucket.publicRead;
      in
      lib.nameValuePair "${resourceName}_public_access" {
        bucket = "\${aws_s3_bucket.${resourceName}.id}";
        block_public_acls = !allowPublic;
        block_public_policy = !allowPublic;
        ignore_public_acls = !allowPublic;
        restrict_public_buckets = !allowPublic;
      }
    ) buckets;

    resource.aws_s3_bucket_website_configuration = lib.mapAttrs' (
      name: bucket:
      let
        resourceName = sanitizeName name;
        website = bucket.website;
      in
      lib.nameValuePair "${resourceName}_website" {
        bucket = "\${aws_s3_bucket.${resourceName}.id}";
        index_document = {
          suffix = website.indexDocument;
        };
        error_document = {
          key = website.errorDocument;
        };
      }
    ) websiteBuckets;

    resource.aws_s3_bucket_policy = lib.mapAttrs' (
      name: bucket:
      let
        resourceName = sanitizeName name;
      in
      lib.nameValuePair "${resourceName}_public_policy" {
        bucket = "\${aws_s3_bucket.${resourceName}.id}";
        policy = builtins.toJSON {
          Version = "2012-10-17";
          Statement = [
            {
              Sid = "PublicReadGetObject";
              Effect = "Allow";
              Principal = "*";
              Action = [ "s3:GetObject" ];
              Resource = "\${aws_s3_bucket.${resourceName}.arn}/*";
            }
          ];
        };
        depends_on = [ "aws_s3_bucket_public_access_block.${resourceName}_public_access" ];
      }
    ) publicBuckets;

    output.s3_bucket_names = {
      description = "Names of created S3 buckets";
      value = lib.mapAttrs (
        name: _: "\${aws_s3_bucket.${sanitizeName name}.bucket}"
      ) buckets;
    };

    output.s3_bucket_domain_names = {
      description = "Regional domain names for S3 buckets";
      value = lib.mapAttrs (
        name: _: "\${aws_s3_bucket.${sanitizeName name}.bucket_regional_domain_name}"
      ) buckets;
    };

    output.s3_bucket_website_endpoints = {
      description = "Website endpoints for buckets with website configuration";
      value = lib.mapAttrs (
        name: _: "\${aws_s3_bucket_website_configuration.${sanitizeName name}_website.website_endpoint}"
      ) websiteBuckets;
    };
  };
}
