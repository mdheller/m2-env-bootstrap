# m2-env-bootstrap

Local-first bootstrap repo for macOS (Apple Silicon) dev environment.

## Run
```bash
./scripts/bootstrap_m2.sh
```

## What this sets up
- Homebrew baseline packages
- mise activation (login shells) + pinned toolchains (python/node/go)
- Podman machine
- Docker CLI + Docker Compose wired to Podman via /var/run/docker.sock (podman-mac-helper)

## Files
- scripts/bootstrap_m2.sh
- scripts/verify.sh
- scripts/snapshot.sh
- docs/NOTES.md
