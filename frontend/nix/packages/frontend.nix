{ pkgs }:

pkgs.stdenv.mkDerivation (finalAttrs: {
  pname = "frontend";
  version = "1.0.0";
  src = ../../.;

  nativeBuildInputs = with pkgs; [
    nodejs_24
    pnpm_10
    pnpmConfigHook
  ];

  pnpmDeps = pkgs.fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    hash = "sha256-Bs2pVZHaFuFjcAsLWR92o2boU/HlmWHcUdu/kaDYenk=";
    fetcherVersion = 3;
  };

  buildPhase = ''
    runHook preBuild
    pnpm build
    runHook postBuild
  '';

  installPhase = ''
    mkdir -p $out
    cp -r dist/* $out/
  '';
})
