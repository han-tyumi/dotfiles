#!/bin/bash
# Bootstrap a fresh Mac from this repo:
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/han-tyumi/dotfiles/main/bootstrap.sh)"
#
# Installs chezmoi, prompts for layers/overlays, generates per-machine SSH keys,
# gates on the age identity when the machine needs it, clones overlay repos, then
# applies — which triggers the run_once scripts (Homebrew, Nix, nix-darwin).
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

# A throwaway chezmoi runs the bootstrap; the applied config installs the real
# one via Nix later.
bindir="$(mktemp -d)"
trap 'rm -rf "$bindir"' EXIT
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$bindir"
chezmoi="$bindir/chezmoi"

# Prompts for layers/overlays and clones the source, without applying yet.
"$chezmoi" init "$REPO"

# shellcheck disable=SC2016 # $-expressions are Go template syntax, not shell
overlays="$("$chezmoi" execute-template \
  '{{ range $name, $url := .overlayUrls }}{{ if has $name $.layerList }}{{ $name }}={{ $url }}{{ "\n" }}{{ end }}{{ end }}')"

# Encrypted targets are decrypted at apply time, so the configured age identity
# must exist first. `managed` honors the layer-driven ignore rules, so machines
# applying nothing encrypted skip this entirely.
if [ -n "$("$chezmoi" managed --include encrypted)" ]; then
  identity="$("$chezmoi" execute-template '{{ .chezmoi.config.age.identity }}')"
  while [ ! -f "$identity" ]; do
    read -r -p ">> Place the age identity at $identity (Bitwarden or backup USB), then press Enter..." _
  done
fi

# Clone enabled overlays before the first apply so the initial rebuild already
# includes them (chezmoi's own external clone has no ssh auth configured yet).
while IFS='=' read -r name url; do
  [ -n "$name" ] || continue
  dir="$HOME/.config/nix-darwin/overlays/$name"
  if [ -d "$dir/.git" ]; then
    echo ">> Overlay '$name' already cloned; skipping."
    continue
  fi
  read -r -p ">> SSH key in ~/.ssh to clone overlay '$name' with: " keyname
  read -r -p ">> Register ~/.ssh/$keyname.pub with the overlay repo's account, then press Enter..." _
  mkdir -p "$(dirname "$dir")"
  GIT_SSH_COMMAND="ssh -i $HOME/.ssh/$keyname" git clone "$url" "$dir"
  git -C "$dir" config core.sshCommand "ssh -i $HOME/.ssh/$keyname"
done <<< "$overlays"

# Applies everything; run_once scripts install Homebrew, Nix, and nix-darwin.
"$chezmoi" apply

echo ">> Bootstrap complete. Open a new shell, then use 'apploi' for rebuilds."
