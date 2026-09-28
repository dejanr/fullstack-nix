{ config, ... }:

let
  inherit (config) infra;
in
{
  imports = [
    ../modules/default.nix
  ];

  terraform.required_providers = {
    aws = {
      source = "hashicorp/aws";
      version = ">= 6.32.1, < 7.0";
    };
  };

  terraform.backend.s3 = {
    bucket = "fullstack-nix-terraform-state-prod";
    key = "terraform/state";
    region = "eu-central-1";
    encrypt = true;
    use_lockfile = true;
  };

  provider.aws = [
    {
      region = "\${var.aws_region}";
    }
    {
      alias = "us_east_1";
      region = "us-east-1";
    }
  ];

  variable.aws_region = {
    type = "string";
    default = "eu-central-1";
  };

  variable.project_name = {
    type = "string";
    default = "fullstack-nix";
  };

  variable.environment = {
    type = "string";
    default = "prod";
  };

  variable.domain = {
    type = "string";
    default = "fullstack-nix.hn.rs";
  };

  aws.acm = {
    main = "\${var.domain}";
  };

  #cloudflare = {
  #  enable = true;
  #  zones = {
  #    "hn.rs" = "41a0f167904f6b5d3d3c024ce1fa47e5";
  #  };
  #};

  aws.cloudfront.main = {
    aliases = [ "\${var.domain}" ];
    certificate = "main";

    origins = {
      static = {
        s3 = "frontend";
        s3Path = "/client";
      };
      frontend = {
        lambda = "frontend";
      };
      backend-example = {
        lambda = "backend-example";
      };
    };

    routes = {
      "/" = {
        origin = "frontend";
      };
      "/assets/*" = {
        origin = "static";
        cache = true;
      };
      "/api/example*" = {
        origin = "backend-example";
      };
    };
  };

  aws.lambda = {
    frontend = {
      handler = "server/handler.handler";
      runtime = "nodejs22.x";
      nixBuild = "frontend#lambda";
      functionUrl = {
        authType = "NONE";
      };
    };
    backend-example = {
      handler = "bootstrap";
      runtime = "provided.al2023";
      nixBuild = "backend/example#lambda";
      functionUrl = {
        authType = "NONE";
      };
    };
  };

  aws.s3 = {
    frontend = {
      publicRead = true;
      publicPolicy = true;
      nixBuilds = {
        client = {
          flake = "frontend#frontend";
          outputPath = "client";
          targetPrefix = "client/";
          cacheControl = "public, max-age=31536000, s-maxage=31536000, immutable";
        };
      };
    };
  };

  aws.iam.githubOidc = {
    enable = true;
    roles = {
      deploy = {
        name = "fullstack-nix-prod-github-deploy";
        subjects = [ "repo:dejanr/fullstack-nix:ref:refs/heads/main" ];
        policyStatements = [
          {
            actions = [ "s3:*" ];
            resources = [ "*" ];
          }
          {
            actions = [ "cloudfront:*" ];
            resources = [ "*" ];
          }
          {
            actions = [ "lambda:*" ];
            resources = [ "*" ];
          }
          {
            actions = [ "iam:*" ];
            resources = [ "*" ];
          }
          {
            actions = [ "acm:*" ];
            resources = [ "*" ];
          }
        ];
      };
      ci = {
        name = "fullstack-nix-prod-github-ci";
        subjects = [
          "repo:dejanr/fullstack-nix:ref:refs/heads/main"
          "repo:dejanr/fullstack-nix:ref:refs/heads/develop"
          "repo:dejanr/fullstack-nix:pull_request"
        ];
        policyStatements = [
          {
            actions = [
              "s3:Get*"
              "s3:List*"
              "cloudfront:Get*"
              "cloudfront:List*"
              "lambda:Get*"
              "lambda:List*"
              "iam:Get*"
              "iam:List*"
              "acm:DescribeCertificate"
              "acm:ListCertificates"
              "acm:ListTagsForCertificate"
            ];
            resources = [ "*" ];
          }
          {
            actions = [
              "s3:PutObject"
              "s3:DeleteObject"
            ];
            resources = [
              "arn:aws:s3:::${config.terraform.backend.s3.bucket}/${config.terraform.backend.s3.key}.tflock"
            ];
          }
          {
            actions = [ "sts:GetCallerIdentity" ];
            resources = [ "*" ];
          }
        ];
      };
    };
  };
}
