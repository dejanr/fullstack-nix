{
  process.manager.implementation = "hivemind";

  processes = {
    backend.exec = ''
      cd $DEVENV_ROOT/backend/example
      nix develop --impure --command bash -c "go run ./cmd/example"
    '';

    frontend.exec = ''
      cd $DEVENV_ROOT/frontend
      nix develop --impure --command bash -c "pnpm dev"
    '';
  };

  enterShell = ''
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  fullstack-nix                                                 ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Development:"
    echo "  devenv up              - Start all services"
    echo "  http://localhost:3000  - Frontend"
    echo "  http://localhost:3001  - Backend Example"
    echo ""
  '';
}
