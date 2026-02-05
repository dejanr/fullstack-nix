# fullstack-nix

A fullstack monorepo example with Nix, featuring a React frontend, Go backend, and AWS infrastructure.

## Structure

- `frontend/` - React + Vite + SSR frontend
- `backend/example/` - Go HTTP server / Lambda backend
- `infra/` - AWS infrastructure (Nix/Terranix/OpenTofu)

## Prerequisites

- Nix + direnv
- AWS credentials configured (for infra deployment)

## Development

```bash
# Enter dev shell
direnv allow

# Frontend
cd frontend && pnpm install && pnpm dev

# Backend
cd backend/example && go run ./cmd/example
```

## Build

```bash
# Frontend
nix build .#frontend
nix build .#frontend-lambda

# Backend
nix build .#backend-example
nix build .#backend-example-lambda

# Infrastructure
nix run .#infra-prod.plan
```
