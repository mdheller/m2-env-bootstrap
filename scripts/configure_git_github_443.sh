#!/usr/bin/env bash
set -euo pipefail

# Rewrite GitHub SSH remotes from git@github.com: to git@github-443:
# This avoids failures on networks that block port 22.

git config --global url."git@github-443:".insteadOf git@github.com:

echo "Configured: git@github.com: -> git@github-443:"
echo
echo "Verify with:"
echo "  git config --global --get-regexp '^url\\..*\\.insteadof$' | grep github"
