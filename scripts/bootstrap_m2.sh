#!/usr/bin/env bash
set -euo pipefail

# m2-env-bootstrap bootstrap script
# - macOS (Apple Silicon) friendly
# - prefers Homebrew for core tools and mise for language toolchains

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log() {
  printf "\n==> %s\n" "$*"
}

die() {
  printf "\nERROR: %s\n" "$*" >&2
  exit 1
}

have() {
  command -v "$1" >/dev/null 2>&1
}

ensure_xcode_clt() {
  if xcode-select -p >/dev/null 2>&1; then
    return
  fi
  die "Xcode Command Line Tools not found. Run: xcode-select --install"
}

ensure_homebrew() {
  if [[ -x /opt/homebrew/bin/brew ]]; then
    # shellenv outputs sh-compatible exports; safe in bash.
    eval "$(/opt/homebrew/bin/brew shellenv)"
    return
  fi

  cat >&2 <<'MSG'
Homebrew not found at /opt/homebrew.

Install it first (official installer):
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

Then re-run:
  ./scripts/bootstrap_m2.sh
MSG
  exit 1
}

ensure_line_in_file() {
  local line="$1"
  local file="$2"

  mkdir -p "$(dirname "$file")"
  touch "$file"

  if grep -Fqx "$line" "$file"; then
    return
  fi

  printf "\n%s\n" "$line" >> "$file"
}

ensure_shell_profiles() {
  log "Ensuring shell profiles include Homebrew and mise"

  # Homebrew: PATH for login shells
  ensure_line_in_file 'eval "$(/opt/homebrew/bin/brew shellenv)"' "$HOME/.zprofile"

  # mise: enable in interactive shells
  ensure_line_in_file 'eval "$(mise activate zsh)"' "$HOME/.zshrc"
  ensure_line_in_file 'eval "$(mise activate bash)"' "$HOME/.bashrc"
}

brew_bundle_install() {
  log "Installing Brewfile packages"

  if [[ ! -f "$REPO_ROOT/Brewfile" ]]; then
    die "Missing Brewfile at $REPO_ROOT/Brewfile"
  fi

  brew update
  brew bundle --file "$REPO_ROOT/Brewfile"
}

mise_pin_toolchains() {
  log "Pinning toolchains with mise (python/node/go)"

  have mise || die "mise is not installed (expected via Brewfile)"

  # Global toolchain versions
  mise use -g python@3.12
  mise use -g node@20
  mise use -g go@1.22
}

ensure_rust() {
  log "Ensuring Rust toolchain (rustup)"

  if [[ -x "$HOME/.cargo/bin/rustc" ]]; then
    return
  fi

  if have rustup-init; then
    rustup-init -y
  elif have rustup; then
    rustup default stable
  else
    log "Rust not installed; install with: brew install rustup"
    return
  fi

  # shellcheck disable=SC1090
  [[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env" || true
}

ensure_docker_compose_plugin_config() {
  log "Configuring Docker CLI to find docker-compose plugin"

  mkdir -p "$HOME/.docker"
  [[ -f "$HOME/.docker/config.json" ]] || printf '{}' > "$HOME/.docker/config.json"

  # Add /opt/homebrew/lib/docker/cli-plugins to cliPluginsExtraDirs
  local tmp
  tmp="$(mktemp)"
  jq '.cliPluginsExtraDirs = ((.cliPluginsExtraDirs // []) + ["/opt/homebrew/lib/docker/cli-plugins"] | unique)' \
    "$HOME/.docker/config.json" > "$tmp"
  mv "$tmp" "$HOME/.docker/config.json"
}

ensure_podman_vfkit_workaround() {
  # On this machine we observed vfkit being blocked/unstable; symlinking podman’s vfkit
  # to the Homebrew vfkit binary made podman machine start reliably.
  have podman || return

  local podman_vfkit brew_vfkit
  podman_vfkit="$(brew --prefix podman)/libexec/podman/vfkit"
  brew_vfkit="$(brew --prefix vfkit)/bin/vfkit"

  [[ -x "$podman_vfkit" ]] || return
  [[ -x "$brew_vfkit" ]] || return

  # If already linked correctly, do nothing.
  if [[ -L "$podman_vfkit" ]] && [[ "$(readlink "$podman_vfkit")" == "$brew_vfkit" ]]; then
    return
  fi

  log "Applying Podman vfkit workaround (symlink to Homebrew vfkit)"

  local backup
  backup="${podman_vfkit}.bak.$(date +%Y%m%d-%H%M%S)"
  mv -f "$podman_vfkit" "$backup"
  ln -sf "$brew_vfkit" "$podman_vfkit"
  log "Backed up: $backup"
}

ensure_podman_machine() {
  log "Ensuring Podman machine is running"

  have podman || die "podman not installed (expected via Brewfile)"

  # Apply workaround before first boot.
  ensure_podman_vfkit_workaround

  if podman machine list 2>/dev/null | awk 'NR>1 {print $1}' | grep -qx 'podman-machine-default'; then
    podman machine start podman-machine-default || true
  else
    podman machine init --now
  fi
}

ensure_podman_mac_helper() {
  log "Ensuring /var/run/docker.sock is provided by podman-mac-helper (requires sudo)"

  # If docker.sock exists, we assume helper is installed.
  if [[ -S /var/run/docker.sock ]]; then
    return
  fi

  local helper
  helper="$(brew --prefix podman)/bin/podman-mac-helper"
  [[ -x "$helper" ]] || die "podman-mac-helper not found at $helper"

  log "Installing podman-mac-helper (sudo prompt expected)"
  sudo "$helper" install

  # Restart the machine so API forwarding binds /var/run/docker.sock
  podman machine stop podman-machine-default || true
  podman machine start podman-machine-default

  [[ -S /var/run/docker.sock ]] || die "/var/run/docker.sock still missing after installing helper"
}

maybe_configure_git_github_443() {
  # If the SSH alias exists, configure git URL rewriting so tools that emit
  # git@github.com: URLs still work on networks that block port 22.
  if [[ -f "$HOME/.ssh/config" ]] && grep -q '^Host github-443$' "$HOME/.ssh/config" 2>/dev/null; then
    git config --global url."git@github-443:".insteadOf git@github.com: || true
  fi
}

print_next_steps() {
  cat <<'MSG'

Done.

Next steps:
  1) Restart your terminal (or run: exec $SHELL -l)
  2) Verify:
       ./scripts/verify.sh

If GitHub SSH port 22 is blocked:
  ./scripts/setup_github_ssh_443.sh
  ./scripts/configure_git_github_443.sh
MSG
}

main() {
  ensure_xcode_clt
  ensure_homebrew
  ensure_shell_profiles
  brew_bundle_install
  mise_pin_toolchains
  ensure_rust
  ensure_docker_compose_plugin_config
  ensure_podman_machine
  ensure_podman_mac_helper
  maybe_configure_git_github_443
  print_next_steps
}

main "$@"
