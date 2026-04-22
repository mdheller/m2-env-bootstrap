# m2-env-bootstrap

Local-first bootstrap repo for a macOS (Apple Silicon) development environment.

## Quick start

Run the bootstrap, then verify the machine state:

```bash
cd ~/dev/m2-env-bootstrap
./scripts/bootstrap_m2.sh
./scripts/verify.sh
```

## What this repo now covers

- Homebrew baseline packages via `Brewfile`
- `mise`-managed shell toolchains for Python, Node, and Go
- Podman machine bootstrap on macOS
- Docker CLI and Compose talking to Podman through `/var/run/docker.sock`
- GitHub CLI (`gh`)
- GitHub SSH over port 443 for networks that block port 22

## GitHub on restricted networks

If standard SSH to GitHub on port 22 times out, use the helper scripts:

```bash
./scripts/setup_github_ssh_443.sh
./scripts/configure_git_github_443.sh
ssh -T git@github-443
```

These configure a `github-443` SSH alias that uses `ssh.github.com:443` and add a git URL rewrite so `git@github.com:` remotes transparently use `git@github-443:`.

## Files

- `Brewfile`
- `scripts/bootstrap_m2.sh`
- `scripts/verify.sh`
- `scripts/snapshot.sh`
- `scripts/setup_github_ssh_443.sh`
- `scripts/configure_git_github_443.sh`
- `docs/NOTES.md`
