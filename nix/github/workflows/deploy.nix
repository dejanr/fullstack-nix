{ steps }:
{
  name = "Deploy";
  on = {
    push = {
      branches = [ "main" ];
      paths = [
        "infra/**"
        "frontend/**"
      ];
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
    deploy = {
      runs-on = "self-hosted";
      steps = [
        steps.checkout
        steps.configureAwsOidc
        {
          name = "Ensure Terraform state bucket";
          working-directory = "infra";
          run = "nix run .#infra-prod.create-state-bucket";
        }
        {
          name = "Deploy prod infrastructure";
          working-directory = "infra";
          run = "nix run .#infra-prod.apply -- -auto-approve";
        }
      ];
    };
  };
}
