# Brewfile for m2-env-bootstrap
#
# Keep this intentionally small & opinionated.
# Add more tools as needed, but avoid overlapping with mise-managed toolchains.

tap "homebrew/bundle"

# Core CLI
brew "git"
brew "jq"
brew "yq"
brew "ripgrep"
brew "fd"
brew "tree"
brew "htop"

# Shell/env
brew "direnv"
brew "mise"

# Networking & crypto
brew "curl"
brew "wget"
brew "openssl@3"
brew "gnupg"
brew "pinentry-mac"

# Python packaging
brew "uv"

# Containers (daemonless local dev)
brew "podman"
brew "vfkit"

# Docker CLI tooling (talks to Podman via /var/run/docker.sock)
brew "docker"
brew "docker-compose"

# GitHub CLI
brew "gh"
