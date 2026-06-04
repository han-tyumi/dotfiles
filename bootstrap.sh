#!/bin/bash
# Bootstrap a fresh Mac from this repo:
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/han-tyumi/dotfiles/main/bootstrap.sh)"
#
# Installs chezmoi and runs `chezmoi init --apply`, which prompts for layers and
# overlays, then triggers the run_once scripts (Homebrew, Nix, nix-darwin).
set -euo pipefail

REPO="han-tyumi"

# Xcode Command Line Tools provide git for chezmoi's clone.
if ! xcode-select -p > /dev/null 2>&1; then
  echo ">> Installing Xcode Command Line Tools; rerun this script once they finish."
  xcode-select --install
  exit 1
fi

# Machine secrets are provisioned by hand; warn early rather than fail late.
if [ ! -f "$HOME/key.txt" ]; then
  echo ">> NOTE: ~/key.txt (age identity) is missing — required before enabling the personal layer."
fi
if ! ls "$HOME"/.ssh/git_* > /dev/null 2>&1; then
  echo ">> NOTE: no ~/.ssh/git_* identity keys found — required for private overlay repos."
fi

sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply "$REPO"

echo ">> Bootstrap complete. Open a new shell, then use 'apploi' for rebuilds."
echo ">> Overlay layers (if any) document their own first-clone step in their README."
