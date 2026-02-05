{ lib, steps }:
{
  name = "frontend";
  on = {
    push = {
      branches = [
        "main"
        "develop"
      ];
      paths = [ "frontend/**" ];
    };
    pull_request = {
      paths = [ "frontend/**" ];
    };
    workflow_dispatch = { };
  };

  jobs = {
    build = {
      runs-on = "ubuntu-latest";
      steps = [
        steps.checkout
        steps.setupNix
        steps.setupMagicCache
        {
          name = "Install dependencies";
          working-directory = "frontend";
          run = "nix develop .#default --impure --command pnpm install";
        }
        {
          name = "Lint";
          working-directory = "frontend";
          run = "nix develop .#default --impure --command pnpm lint";
        }
        {
          name = "Type check";
          working-directory = "frontend";
          run = "nix develop .#default --impure --command pnpm typecheck";
        }
        {
          name = "Test";
          working-directory = "frontend";
          run = "nix develop .#default --impure --command pnpm test";
        }
        {
          name = "JS Build";
          working-directory = "frontend";
          run = "nix develop .#default --impure --command pnpm build";
        }
        {
          name = "Nix build";
          working-directory = "frontend";
          run = "nix build .#frontend";
        }
      ];
    };
  };
}
