\
#!/usr/bin/env bash
set -euo pipefail

log(){ printf "\n[%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
die(){ printf "\n[ERROR] %s\n" "$*" >&2; exit 1; }

log "Sanity check: macOS arm64 expected"
[ "$(uname -s)" = "Darwin" ] || die "Not macOS"
[ "$(uname -m)" = "arm64" ] || die "Not arm64"

log "Ensure Homebrew exists and is on PATH"
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv zsh)"
else
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv zsh)"
fi

log "Install baseline packages (idempotent)"
brew update
brew install mise uv podman vfkit qemu docker docker-compose jq >/dev/null

log "Ensure mise activates in login shells (~/.zprofile)"
grep -q 'eval "\$\(\/opt\/homebrew\/bin\/brew shellenv zsh\)"' "$HOME/.zprofile" 2>/dev/null || echo 'eval "$(/opt/homebrew/bin/brew shellenv zsh)"' >> "$HOME/.zprofile"
grep -q 'mise activate zsh' "$HOME/.zprofile" 2>/dev/null || echo 'eval "$(mise activate zsh)"' >> "$HOME/.zprofile"

log "Pin global toolchains (safe if already installed)"
mise use -g python@3.12 node@20 go@1.22 || true

log "Start podman machine"
podman machine init --now 2>/dev/null || true

# If start fails due to vfkit issues, apply vfkit workaround (symlink podman vfkit -> brew vfkit)
if ! podman machine start 2>/dev/null; then
  log "Podman machine start failed; attempting vfkit workaround"
  POD_VFKIT="$(brew --prefix podman)/libexec/podman/vfkit"
  BREW_VFKIT="$(brew --prefix vfkit)/bin/vfkit"
  if [ -e "$POD_VFKIT" ] && [ -x "$BREW_VFKIT" ]; then
    [ -e "${POD_VFKIT}.bak" ] || ( [ -f "$POD_VFKIT" ] && mv -f "$POD_VFKIT" "${POD_VFKIT}.bak" ) || true
    ln -sf "$BREW_VFKIT" "$POD_VFKIT"
  fi
  podman machine start
fi

log "Install podman mac helper for /var/run/docker.sock (sudo once)"
sudo "$(brew --prefix podman)/bin/podman-mac-helper" install || true

log "Restart podman machine to enable /var/run/docker.sock forwarding"
podman machine stop podman-machine-default 2>/dev/null || true
podman machine start podman-machine-default

log "Enable docker compose plugin discovery"
mkdir -p "$HOME/.docker"
python3 - <<'PYC'
import json
from pathlib import Path
cfg = Path.home()/".docker"/"config.json"
data = {}
if cfg.exists():
    try: data = json.loads(cfg.read_text())
    except Exception: data = {}
dirs = data.get("cliPluginsExtraDirs", [])
want = "/opt/homebrew/lib/docker/cli-plugins"
if want not in dirs: dirs.append(want)
data["cliPluginsExtraDirs"] = sorted(set(dirs))
cfg.write_text(json.dumps(data, indent=2) + "\n")
print("Updated", cfg)
PYC

log "Verify docker -> podman"
docker version
docker run --rm alpine:latest uname -a
docker compose version || true

log "Done."
