# Example Backend

Minimal Go HTTP server example.

## Endpoints

- `GET /` - Returns `{"message": "Hello, World!"}`
- `GET /health` - Health check

## Local development

```bash
cd backend/example
direnv allow
go run ./cmd/example
```

## Build with Nix

```bash
nix build .#example
```
