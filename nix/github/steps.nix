{
  checkout = {
    uses = "actions/checkout@v6.0.2";
  };

  setupNix = {
    uses = "DeterminateSystems/determinate-nix-action@v3.15.1";
  };

  setupMagicCache = {
    uses = "DeterminateSystems/magic-nix-cache-action@v13";
    "with" = {
      use-flakehub = false;
    };
  };

  configureAwsOidc = roleArn: {
    name = "Configure AWS credentials";
    uses = "aws-actions/configure-aws-credentials@v5.1.1";
    "with" = {
      role-to-assume = roleArn;
      aws-region = "\${{ env.AWS_REGION }}";
    };
  };
}
