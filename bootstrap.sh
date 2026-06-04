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

# Generate per-machine SSH identity keys; public keys get registered with the
# matching GitHub account, so no key material is ever transported.
read -r -p ">> SSH identity keys to generate (space-separated, e.g. 'git_han-tyumi git_chmmpagne'; empty to skip): " ssh_keys
# shellcheck disable=SC2086 # word splitting is the input format
for name in $ssh_keys; do
  key="$HOME/.ssh/$name"
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  if [ -f "$key" ]; then
    echo ">> $key already exists; skipping."
  else
    ssh-keygen -t ed25519 -N "" -C "$name@$(hostname -s)" -f "$key"
  fi
  echo ">> Public key for $name — add it at https://github.com/settings/keys:"
  cat "$key.pub"
done

# Machine secrets that cannot be generated are provisioned by hand; warn early.
if [ ! -f "$HOME/key.txt" ]; then
  echo ">> NOTE: ~/key.txt (age identity) is missing — required before enabling the personal layer."
fi

sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply "$REPO"

echo ">> Bootstrap complete. Open a new shell, then use 'apploi' for rebuilds."
echo ">> Overlay layers (if any) document their own first-clone step in their README."
