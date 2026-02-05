{ pkgs, ... }:

{
  dotenv.enable = true;

  languages.opentofu.enable = true;

  packages = with pkgs; [
    awscli2
    opentofu
    tflint
    zip
  ];

  env.AWS_DEFAULT_REGION = "eu-central-1";

  scripts = {
  };

  enterShell = ''
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  fullstack-nix - infra                                         ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "AWS Authentication Required:"
    echo ""
    echo "  aws sts get-caller-identity"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Infrastructure Commands:"
    echo ""
    echo "  Prod Environment:"
    echo "    nix run .#infra-prod.plan              # Plan changes"
    echo "    nix run .#infra-prod.deploy            # Deploy with confirmation"
    echo "    nix run .#infra-prod.apply             # Apply changes"
    echo "    nix run .#infra-prod.destroy           # Destroy infrastructure"
    echo ""
    echo "  State Management:"
    echo "    nix run .#infra-prod.state-list           # List resources"
    echo "    nix run .#infra-prod.state-show <res>     # Show resource details"
    echo "    nix run .#infra-prod.state-pull           # Pull current state"
    echo "    nix run .#infra-prod.import <res> <id>    # Import existing resource"
    echo "    nix run .#infra-prod.force-unlock <id>    # Force unlock state"
    echo ""
    echo "  Setup:"
    echo "    nix run .#infra-prod.create-state-bucket  # Create state bucket if missing"
    echo ""
  '';
}
