#!/usr/bin/env bash
set -euo pipefail
OUTDIR="${1:-$HOME/dev/m2-env-bootstrap/.snapshots/$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$OUTDIR"
brew bundle dump --file="$OUTDIR/Brewfile" --force
mise current > "$OUTDIR/mise.current.txt" || true
podman info > "$OUTDIR/podman.info.txt" || true
docker version > "$OUTDIR/docker.version.txt" || true
docker compose version > "$OUTDIR/docker.compose.version.txt" || true
echo "Wrote snapshot to: $OUTDIR"
