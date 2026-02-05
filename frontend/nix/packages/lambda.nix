{ pkgs }:

pkgs.stdenv.mkDerivation (finalAttrs: {
  pname = "frontend-lambda";
  version = "1.0.0";
  src = ../../.;

  nativeBuildInputs = with pkgs; [
    nodejs_24
    pnpm_10
    pnpmConfigHook
    zip
  ];

  pnpmDeps = pkgs.fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    hash = "sha256-Bs2pVZHaFuFjcAsLWR92o2boU/HlmWHcUdu/kaDYenk=";
    fetcherVersion = 3;
  };

  buildPhase = ''
    runHook preBuild
    pnpm build
    
    # Compile the handler for Lambda
    pnpm exec tsc server/handler.ts --outDir dist/server --module NodeNext --moduleResolution NodeNext --target ES2022
    runHook postBuild
  '';

  installPhase = ''
    mkdir -p $out

    # Copy server bundle (includes compiled handler)
    cp -r dist/server $out/
    cp -r dist/client $out/

    # Add package.json for ES modules support
    echo '{"type": "module"}' > $out/package.json

    # Create lambda zip with correct structure
    cd $out && zip -r lambda.zip server client package.json
  '';
})
