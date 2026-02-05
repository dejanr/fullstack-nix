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

```bash
aws configure
# or
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...

# Verify
aws sts get-caller-identity
```

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
