{ steps, ... }:
{
  name = "infra";
  on = {
    push = {
      branches = [
        "main"
        "develop"
      ];
      paths = [ "infra/**" ];
    };
    pull_request = {
      paths = [ "infra/**" ];
    };
    workflow_dispatch = { };
  };

  permissions = {
    id-token = "write";
    contents = "read";
  };

  env = {
    AWS_REGION = "eu-central-1";
    CLOUDFLARE_API_TOKEN = "\${{ secrets.CLOUDFLARE_API_TOKEN }}";
  };

  concurrency = {
    group = "infra-prod";
    cancel-in-progress = false;
  };

  jobs = {
    validate = {
      runs-on = "ubuntu-latest";
      steps = [
        steps.checkout
        steps.setupNix
        steps.setupMagicCache
        steps.configureAwsOidc
        {
          name = "Generate and validate Terraform config";
          working-directory = "infra";
          run = ''
            nix run .#infra-prod.init
            nix run .#infra-prod.plan
          '';
        }
      ];
    };
  };
}
