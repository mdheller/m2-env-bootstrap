#!/usr/bin/env bash
set -euo pipefail

# Lightweight verification (minimal network usage).

check_cmd() {
  local cmd="$1"
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "$cmd: $(command -v "$cmd")"
    return 0
  fi
  echo "$cmd: (missing)"
  return 1
}

check_cmd brew || true
brew --version 2>/dev/null | head -n 1 || true

echo
check_cmd mise || true
mise --version 2>/dev/null | head -n 2 || true
mise current 2>/dev/null || true

echo
if command -v python3 >/dev/null 2>&1; then echo "python: $(python3 --version)"; else echo "python: (missing)"; fi
if command -v node >/dev/null 2>&1; then echo "node:   $(node --version)"; else echo "node:   (missing)"; fi
if command -v go >/dev/null 2>&1; then echo "go:     $(go version)"; else echo "go:     (missing)"; fi

if [[ -x "$HOME/.cargo/bin/rustc" ]]; then
  echo "rustc:  $($HOME/.cargo/bin/rustc --version)"
else
  echo "rustc:  (missing)"
fi

echo
if command -v podman >/dev/null 2>&1; then
  echo "podman (client):"
  podman --version || true
  echo "podman info (head):"
  podman info 2>/dev/null | sed -n '1,80p' || true
else
  echo "podman: (missing)"
fi

echo
if command -v docker >/dev/null 2>&1; then
  echo "docker version (head):"
  docker version 2>/dev/null | sed -n '1,80p' || true
else
  echo "docker: (missing)"
fi

docker compose version 2>/dev/null || true

echo
if [[ -S /var/run/docker.sock ]]; then
  echo "docker.sock: /var/run/docker.sock exists"
else
  echo "docker.sock: MISSING (/var/run/docker.sock)"
fi

echo
if [[ -f "$HOME/.ssh/config" ]] && grep -q '^Host github-443$' "$HOME/.ssh/config" 2>/dev/null; then
  echo "ssh github-443 config:";
  ssh -G github-443 2>/dev/null | egrep '^(hostname|port|user|identityfile|identitiesonly) ' || true
fi
