{ pkgs, ... }:

{
  languages.javascript = {
    enable = true;
    package = pkgs.nodejs_24;
    pnpm = {
      enable = true;
      package = pkgs.pnpm_10;
    };
  };

  enterShell = ''
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  Frontend                                                      ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Commands:"
    echo "  pnpm install         - Install dependencies"
    echo "  pnpm dev             - Run SSR dev server"
    echo "  pnpm build           - Build for production"
    echo "  pnpm test            - Run tests"
    echo "  pnpm lint            - Run ESLint"
    echo "  pnpm typecheck       - Run TypeScript type checking"
    echo ""
    echo "Nix outputs:"
    echo "  nix build .#frontend - Build the frontend with Nix"
    echo "  nix build .#lambda   - Build Lambda package"
    echo ""
  '';
}
