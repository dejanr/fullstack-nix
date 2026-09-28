# Infrastructure

Infrastructure as code for fullstack-nix using Nix, Terranix, and OpenTofu on AWS.

## Tech Stack

- **Terranix** - Nix-based Terraform configuration
- **OpenTofu** - Infrastructure provisioning
- **AWS** - Cloud provider (Lambda, CloudFront, S3, ACM)
- **Cloudflare** - DNS management

## Getting Started

```bash
cd infra
direnv allow
```

### AWS Authentication

Use AWS CLI v2 to sign in locally with temporary credentials:

```bash
aws login
aws sts get-caller-identity
```

The pinned OpenTofu and AWS provider versions support this login directly—no
credential exports are needed. Run `aws login` again when the session expires.
For a named profile, use `aws login --profile <name>` and set
`AWS_PROFILE=<name>` when running the infrastructure commands.

### GitHub Actions Authentication

CI uses GitHub Actions OIDC, not local login credentials or long-lived AWS keys.
The AWS account must already have an IAM OIDC provider for
`https://token.actions.githubusercontent.com` with audience `sts.amazonaws.com`;
the infrastructure looks up this existing provider.

Bootstrap the roles locally using an AWS identity with provisioning permissions
(commands below run from `infra/`):

```bash
aws login
aws sts get-caller-identity
nix run .#infra-prod.create-state-bucket
nix run .#infra-prod.plan
nix run .#infra-prod.apply
nix run .#infra-prod.output -- -json github_oidc_role_arns
```

Review the plan before applying: these commands manage the full production
infrastructure, not just the OIDC roles.

Configure these repository secrets under **Settings → Secrets and variables →
Actions**:

| Secret | Value |
| --- | --- |
| `AWS_CI_ROLE_ARN` | The `ci` ARN from `github_oidc_role_arns` |
| `AWS_DEPLOY_ROLE_ARN` | The `deploy` ARN from `github_oidc_role_arns` |
| `CLOUDFLARE_API_TOKEN` | A token with the required DNS permissions, when Cloudflare is enabled |

The deploy role trusts only `main` in `dejanr/fullstack-nix`. The CI role trusts
`main`, `develop`, and pull requests, with read permissions for the configured
AWS services and write/delete access only to the state lock object. Fork pull
requests do not receive repository secrets and cannot run the authenticated plan.
Only trusted contributors should be allowed to run this plan with credentials:
Terraform configuration and build scripts execute code, and state can contain
sensitive data.

Both workflows require `id-token: write`. Missing role secrets cause
`Credentials could not be loaded` because the action receives no role to assume.
Local AWS login does not configure these secrets. Rerun CI after bootstrapping the
roles and setting the secrets.

Workflow YAML is generated. Edit `nix/github/steps.nix` and the workflow definitions
under `infra/nix/github/workflows/` and `nix/github/workflows/`, then run
`nix run .#render-workflows` from the repository root.

## Commands

```bash
nix run .#infra-prod.plan      # Preview changes
nix run .#infra-prod.apply     # Apply changes
nix run .#infra-prod.deploy    # Apply with confirmation
nix run .#infra-prod.destroy   # Destroy all resources
```

State management:

```bash
nix run .#infra-prod.create-state-bucket  # Create S3 state bucket (one-time)
nix run .#infra-prod.state-list           # List managed resources
nix run .#infra-prod.state-show <res>     # Show resource details
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         CloudFront                               │
│                    (fullstack-nix.hn.rs)                         │
├─────────────────────────────────────────────────────────────────┤
│  /assets/*      →  S3 Bucket (static assets)                    │
│  /api/example*  →  Backend Lambda (Go)                          │
│  /*             →  Frontend Lambda (Node.js SSR)                │
└─────────────────────────────────────────────────────────────────┘
```

## Project Structure

```
infra/
├── config/
│   ├── prod.nix              # Production environment config
│   └── terraform/prod/       # Generated Terraform files
├── modules/
│   ├── aws/
│   │   ├── acm/              # SSL certificates
│   │   ├── cloudfront/       # CDN distribution
│   │   ├── iam/              # IAM roles
│   │   ├── lambda/           # Lambda functions
│   │   ├── s3/               # S3 buckets
│   │   └── secretsmanager/   # Secrets
│   └── cloudflare/           # DNS records
├── devenv.nix
├── flake.nix
└── README.md
```

## Deployment

### 1. Create Terraform State Bucket

```bash
nix run .#infra-prod.create-state-bucket
```

### 2. Deploy Infrastructure

```bash
nix run .#infra-prod.deploy
```

### 3. Configure Cloudflare

Add the zone ID to `config/prod.nix`:

```nix
cloudflare = {
  enable = true;
  zones = {
    "hn.rs" = "your-zone-id";
  };
};
```

DNS records will be automatically created for CloudFront and ACM validation.
