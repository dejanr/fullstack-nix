{
  description = "fullstack-nix infrastructure";

  inputs = {
    devenv-root = {
      url = "file+file:///dev/null";
      flake = false;
    };
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";
    devenv.url = "github:cachix/devenv";
    devenv.inputs.nixpkgs.follows = "nixpkgs";
    devenv.inputs.flake-parts.follows = "flake-parts";
    terranix.url = "github:terranix/terranix";
    terranix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{
      flake-parts,
      ...
    }:
    let
      mkInfraPackage =
        {
          pkgs,
          system,
          env,
          envConfig,
          stateBucketName,
          stateRegion,
        }:
        let
          terraformConfig = inputs.terranix.lib.terranixConfiguration {
            inherit system;
            modules = [
              ./modules/default.nix
              envConfig
            ];
          };
          # Source .env file if it exists
          loadEnv = ''
            PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")
            if [ -f "$PROJECT_ROOT/infra/.env" ]; then
              set -a
              source "$PROJECT_ROOT/infra/.env"
              set +a
            fi
          '';
        in
        pkgs.runCommand "infra-${env}"
          {
            passthru = {
              init = pkgs.writeShellScriptBin "infra-${env}-init" ''
                PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")
                WORK_DIR="$PROJECT_ROOT/infra/config/terraform/${env}"
                mkdir -p "$WORK_DIR"
                rm -f "$WORK_DIR/config.tf.json"
                cp "${terraformConfig}" "$WORK_DIR/config.tf.json"
                "${pkgs.opentofu}/bin/tofu" -chdir="$WORK_DIR" init
              '';

              plan = pkgs.writeShellScriptBin "infra-${env}-plan" ''
                ${loadEnv}
                WORK_DIR="$PROJECT_ROOT/infra/config/terraform/${env}"
                mkdir -p "$WORK_DIR"
                rm -f "$WORK_DIR/config.tf.json"
                cp "${terraformConfig}" "$WORK_DIR/config.tf.json"
                "${pkgs.opentofu}/bin/tofu" -chdir="$WORK_DIR" init -upgrade
                "${pkgs.opentofu}/bin/tofu" -chdir="$WORK_DIR" plan "$@"
              '';

              output = pkgs.writeShellScriptBin "infra-${env}-output" ''
                PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")
                WORK_DIR="$PROJECT_ROOT/infra/config/terraform/${env}"
                mkdir -p "$WORK_DIR"
                rm -f "$WORK_DIR/config.tf.json"
                cp "${terraformConfig}" "$WORK_DIR/config.tf.json"
                "${pkgs.opentofu}/bin/tofu" -chdir="$WORK_DIR" init -upgrade
                "${pkgs.opentofu}/bin/tofu" -chdir="$WORK_DIR" output "$@"
              '';

              apply = pkgs.writeShellScriptBin "infra-${env}-apply" ''
                ${loadEnv}
                WORK_DIR="$PROJECT_ROOT/infra/config/terraform/${env}"
                mkdir -p "$WORK_DIR"
                rm -f "$WORK_DIR/config.tf.json"
                cp "${terraformConfig}" "$WORK_DIR/config.tf.json"
                "${pkgs.opentofu}/bin/tofu" -chdir="$WORK_DIR" init -upgrade
                "${pkgs.opentofu}/bin/tofu" -chdir="$WORK_DIR" apply "$@"
              '';

              deploy = pkgs.writeShellScriptBin "infra-${env}-deploy" ''
                ${loadEnv}
                WORK_DIR="$PROJECT_ROOT/infra/config/terraform/${env}"

                echo "Deploying ${env} environment to AWS..."
                echo ""

                mkdir -p "$WORK_DIR"
                rm -f "$WORK_DIR/config.tf.json"
                cp "${terraformConfig}" "$WORK_DIR/config.tf.json"
                "${pkgs.opentofu}/bin/tofu" -chdir="$WORK_DIR" init -upgrade
                "${pkgs.opentofu}/bin/tofu" -chdir="$WORK_DIR" plan

                echo ""
                read -p "Apply changes? (y/N): " -r confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                  "${pkgs.opentofu}/bin/tofu" -chdir="$WORK_DIR" apply
                  echo "Deployment complete!"
                else
                  echo "Deployment cancelled"
                  exit 1
                fi
              '';

              destroy = pkgs.writeShellScriptBin "infra-${env}-destroy" ''
                ${loadEnv}
                WORK_DIR="$PROJECT_ROOT/infra/config/terraform/${env}"

                echo "WARNING: This will destroy all infrastructure in ${env} environment!"
                echo ""

                mkdir -p "$WORK_DIR"
                rm -f "$WORK_DIR/config.tf.json"
                cp "${terraformConfig}" "$WORK_DIR/config.tf.json"
                "${pkgs.opentofu}/bin/tofu" -chdir="$WORK_DIR" init -upgrade
                "${pkgs.opentofu}/bin/tofu" -chdir="$WORK_DIR" destroy "$@"
              '';

              state-list = pkgs.writeShellScriptBin "infra-${env}-state-list" ''
                PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")
                WORK_DIR="$PROJECT_ROOT/infra/config/terraform/${env}"
                "${pkgs.opentofu}/bin/tofu" -chdir="$WORK_DIR" state list "$@"
              '';

              state-show = pkgs.writeShellScriptBin "infra-${env}-state-show" ''
                PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")
                WORK_DIR="$PROJECT_ROOT/infra/config/terraform/${env}"
                "${pkgs.opentofu}/bin/tofu" -chdir="$WORK_DIR" state show "$@"
              '';

              state-pull = pkgs.writeShellScriptBin "infra-${env}-state-pull" ''
                PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")
                WORK_DIR="$PROJECT_ROOT/infra/config/terraform/${env}"
                "${pkgs.opentofu}/bin/tofu" -chdir="$WORK_DIR" state pull
              '';

              import = pkgs.writeShellScriptBin "infra-${env}-import" ''
                ${loadEnv}
                WORK_DIR="$PROJECT_ROOT/infra/config/terraform/${env}"
                mkdir -p "$WORK_DIR"
                rm -f "$WORK_DIR/config.tf.json"
                cp "${terraformConfig}" "$WORK_DIR/config.tf.json"
                "${pkgs.opentofu}/bin/tofu" -chdir="$WORK_DIR" init -upgrade
                "${pkgs.opentofu}/bin/tofu" -chdir="$WORK_DIR" import "$@"
              '';

              force-unlock = pkgs.writeShellScriptBin "infra-${env}-force-unlock" ''
                PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")
                WORK_DIR="$PROJECT_ROOT/infra/config/terraform/${env}"
                "${pkgs.opentofu}/bin/tofu" -chdir="$WORK_DIR" force-unlock -force "$@"
              '';

              create-state-bucket = pkgs.writeShellScriptBin "infra-${env}-create-state-bucket" ''
                BUCKET_NAME="${stateBucketName}"
                REGION="${stateRegion}"

                echo "Ensuring Terraform state bucket exists: $BUCKET_NAME"
                echo "Region: $REGION"
                echo ""

                if "${pkgs.awscli2}/bin/aws" s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
                  echo "State bucket already exists."
                else
                  if [ "$REGION" = "us-east-1" ]; then
                    "${pkgs.awscli2}/bin/aws" s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION"
                  else
                    "${pkgs.awscli2}/bin/aws" s3api create-bucket \
                      --bucket "$BUCKET_NAME" \
                      --region "$REGION" \
                      --create-bucket-configuration LocationConstraint="$REGION"
                  fi

                  "${pkgs.awscli2}/bin/aws" s3api put-bucket-versioning \
                    --bucket "$BUCKET_NAME" \
                    --versioning-configuration Status=Enabled

                  "${pkgs.awscli2}/bin/aws" s3api put-public-access-block \
                    --bucket "$BUCKET_NAME" \
                    --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

                  echo "State bucket created."
                fi
              '';
            };
          }
          ''
            mkdir -p $out
            cp ${terraformConfig} $out/config.tf.json
          '';
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.devenv.flakeModule ];

      systems = [
        "x86_64-linux"
        "x86_64-darwin"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      perSystem =
        {
          config,
          pkgs,
          system,
          ...
        }:
        {
          formatter = pkgs.nixfmt-tree;

          packages = {
            default = config.packages.infra-prod;

            infra-prod = mkInfraPackage {
              inherit pkgs system;
              env = "prod";
              envConfig = ./config/prod.nix;
              stateBucketName = "fullstack-nix-terraform-state-prod";
              stateRegion = "eu-central-1";
            };
          };

          devenv.shells.default = {
            name = "fullstack-nix-infra";

            imports = [ ./devenv.nix ];
          };
        };
    };
}
