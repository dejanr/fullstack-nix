{ steps, ... }:
{
  name = "backend/example";
  on = {
    push = {
      branches = [
        "main"
        "develop"
      ];
      paths = [ "backend/example/**" ];
    };
    pull_request = {
      paths = [ "backend/example/**" ];
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
          name = "Go Build";
          working-directory = "backend/example";
          run = "nix develop .#default --impure --command go build ./cmd/example";
        }
        {
          name = "Nix Build";
          working-directory = "backend/example";
          run = "nix build .#example";
        }
        {
          name = "Test";
          working-directory = "backend/example";
          run = "nix develop .#default --impure --command go test ./...";
        }
      ];
    };
  };
}
