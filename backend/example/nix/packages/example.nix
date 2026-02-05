{ pkgs }:

pkgs.buildGoModule {
  pname = "backend-example";
  version = "1.0.0";
  src = ../../.;

  subPackages = [ "cmd/example" ];

  env = {
    CGO_ENABLED = "0";
  };

  ldflags = [
    "-s"
    "-w"
  ];

  vendorHash = "sha256-GO53ToOyUSWOH1JXsHMrxMLWeZTYVFso2AwubhJ1tfc=";
}
