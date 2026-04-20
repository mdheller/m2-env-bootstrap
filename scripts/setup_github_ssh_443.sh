#!/usr/bin/env bash
set -euo pipefail

# Create (if missing) and configure a GitHub SSH key intended to work on networks
# where github.com:22 is blocked. Uses ssh.github.com:443 via host alias github-443.

KEY_PATH="${1:-$HOME/.ssh/id_ed25519_github}"
COMMENT="${2:-github-$(hostname)-$(date +%Y%m%d)}"

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

touch "$HOME/.ssh/config"
chmod 600 "$HOME/.ssh/config"

if [[ ! -f "$KEY_PATH" ]]; then
  echo "Generating key: $KEY_PATH"
  ssh-keygen -t ed25519 -a 64 -f "$KEY_PATH" -C "$COMMENT"
else
  echo "Key already exists: $KEY_PATH (skipping generation)"
fi

# Append host alias if not present.
if ! grep -q '^Host github-443$' "$HOME/.ssh/config" 2>/dev/null; then
  cat >> "$HOME/.ssh/config" <<EOF_GH443

Host github-443
  HostName ssh.github.com
  Port 443
  User git
  IdentityFile $KEY_PATH
  IdentitiesOnly yes
  AddKeysToAgent yes
  UseKeychain yes
EOF_GH443
  echo "Added SSH host alias: github-443"
else
  echo "SSH host alias github-443 already present (not modifying)"
fi

# Start agent if needed
if ! ssh-add -l >/dev/null 2>&1; then
  eval "$(ssh-agent -s)" >/dev/null
fi

# Add to agent (macOS keychain flags vary by version)
ssh-add --apple-use-keychain "$KEY_PATH" 2>/dev/null \
  || ssh-add -K "$KEY_PATH" 2>/dev/null \
  || ssh-add "$KEY_PATH"

echo
echo "Public key (add this to GitHub):"
cat "${KEY_PATH}.pub"

echo
echo "Test connection (will succeed only after key is added to GitHub):"
ssh -T git@github-443 || true
