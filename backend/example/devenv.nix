{
  env.PORT = "3001";

  languages.go.enable = true;

  enterShell = ''
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  Example Backend                                               ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Commands:"
    echo "  go run ./cmd/example    - Start the server"
    echo ""
    echo "Nix outputs:"
    echo "  nix build .#example - Build main backend go package"
    echo "  nix build .#lambda  - Build lambda go package"
    echo ""
  '';
}
