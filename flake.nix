{
  description = "fullstack-nix";

  inputs = {
    devenv-root = {
      url = "file+file:///dev/null";
      flake = false;
    };
    nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";
    devenv.url = "github:cachix/devenv";
    devenv.inputs.nixpkgs.follows = "nixpkgs";
    devenv.inputs.flake-parts.follows = "flake-parts";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    actions-nix.url = "github:nialov/actions.nix";
    actions-nix.inputs.nixpkgs.follows = "nixpkgs";
    backend-example.url = "path:./backend/example";
    frontend.url = "path:./frontend";
    infra.url = "path:./infra";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.devenv.flakeModule
        inputs.actions-nix.flakeModules.default
      ];

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
            default = config.devenv.shells.default.config.ci;
            backend-example = inputs.backend-example.packages.${system}.example;
            backend-example-lambda = inputs.backend-example.packages.${system}.lambda;
            frontend = inputs.frontend.packages.${system}.frontend;
            frontend-lambda = inputs.frontend.packages.${system}.lambda;
            infra-prod = inputs.infra.packages.${system}.infra-prod;
          };

          devenv.shells.default = {
            name = "fullstack-nix";

            imports = [ ./devenv.nix ];
          };
        };

      flake.actions-nix =
        let
          lib = inputs.nixpkgs.lib;
          steps = import ./nix/github/steps.nix;
        in
        {
          pre-commit.enable = true;

          workflows = {
            ".github/workflows/backend-example-ci.yml" = import ./backend/example/nix/github/workflows/ci.nix {
              inherit lib steps;
            };
            ".github/workflows/frontend-ci.yml" = import ./frontend/nix/github/workflows/ci.nix {
              inherit lib steps;
            };
            ".github/workflows/infra-ci.yml" = import ./infra/nix/github/workflows/ci.nix {
              inherit lib steps;
            };
            ".github/workflows/infra-deploy.yml" = import ./nix/github/workflows/deploy.nix {
              inherit lib steps;
            };
          };
        };
    };
}
