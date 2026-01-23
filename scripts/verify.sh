#!/usr/bin/env bash
set -euo pipefail
echo "brew: $(command -v brew || true)"
brew --version || true
echo "mise: $(command -v mise || true)"
mise current || true
echo "python: $(python3 --version 2>/dev/null || true)"
echo "node: $(node --version 2>/dev/null || true)"
echo "go: $(go version 2>/dev/null || true)"
echo "podman:"
podman info | head -n 50 || true
echo "docker:"
docker version || true
docker compose version || true
