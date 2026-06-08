#!/bin/bash
# Bootstrap a fresh Mac from this repo:
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/han-tyumi/dotfiles/main/bootstrap.sh)"
#
# Installs chezmoi, prompts for layers/overlays, generates per-machine SSH keys,
# clones overlay repos, then applies — which triggers the run_once scripts
# (Homebrew, Nix, nix-darwin).
#
# Unattended runs: pass --promptString "layers=...,overlays=..." (forwarded to
# chezmoi init) and preset the interactive prompts via environment variables:
#   DOTFILES_SSH_KEYS="git_a git_b"         keys to generate (set empty to skip)
#   DOTFILES_OVERLAY_KEYS="work=git_b ..."  ssh key name per overlay clone
set -euo pipefail

REPO="han-tyumi"

# Prompts target the terminal directly: mid-script stdin may be redirected (the
# overlay loop reads a here-string), and unattended runs have no terminal at all.
if { : < /dev/tty; } 2> /dev/null; then
  prompt() { read -r -p "$1" "$2" < /dev/tty; }
else
  prompt() {
    echo ">> No terminal to answer: $1" >&2
    echo ">> Preset the matching DOTFILES_* variable for unattended runs." >&2
    return 1
  }
fi

# Xcode Command Line Tools provide git for chezmoi's clone.
if ! xcode-select -p > /dev/null 2>&1; then
  echo ">> Installing Xcode Command Line Tools; rerun this script once they finish."
  xcode-select --install
  exit 1
fi

# Generate per-machine SSH identity keys; public keys get registered with the
# matching GitHub account, so no key material is ever transported.
if [ -n "${DOTFILES_SSH_KEYS+set}" ]; then
  ssh_keys="$DOTFILES_SSH_KEYS"
else
  prompt ">> SSH identity keys to generate (space-separated, e.g. 'git_han-tyumi git_chmmpagne'; empty to skip): " ssh_keys
fi
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
# shellcheck disable=SC2086 # word splitting is the input format
for name in $ssh_keys; do
  key="$HOME/.ssh/$name"
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
# Extra script args (e.g. --promptString "layers=...") pass through for
# unattended runs.
"$chezmoi" init "$@" "$REPO"

# shellcheck disable=SC2016 # $-expressions are Go template syntax, not shell
overlays="$("$chezmoi" execute-template \
  '{{ range $name, $url := .enabledOverlays }}{{ $name }}={{ $url }}{{ "\n" }}{{ end }}')"

# Clone enabled overlays before the first apply so the initial rebuild already
# includes them (chezmoi's own external clone has no ssh auth configured yet).
while IFS='=' read -r name url; do
  [ -n "$name" ] || continue
  dir="$HOME/.config/nix-darwin/overlays/$name"
  if [ -d "$dir/.git" ]; then
    echo ">> Overlay '$name' already cloned; skipping."
    continue
  fi
  keyname=""
  # shellcheck disable=SC2086 # word splitting is the input format
  for pair in ${DOTFILES_OVERLAY_KEYS:-}; do
    case $pair in
    "$name"=*) keyname="${pair#*=}" ;;
    esac
  done
  if [ -z "$keyname" ]; then
    prompt ">> SSH key in ~/.ssh to clone overlay '$name' with: " keyname
    prompt ">> Register ~/.ssh/$keyname.pub with the overlay repo's account, then press Enter..." _
  fi
  mkdir -p "$(dirname "$dir")"
  # accept-new: a fresh Mac has no known_hosts entry yet, and the loop's stdin
  # (the here-string) can't answer ssh's host-key prompt.
  GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new -i $HOME/.ssh/$keyname" \
    git clone "$url" "$dir"
  git -C "$dir" config core.sshCommand "ssh -i $HOME/.ssh/$keyname"
done <<< "$overlays"

# Applies everything; run_once scripts install Homebrew, Nix, and nix-darwin.
"$chezmoi" apply

echo ">> Bootstrap complete. Open a new shell, then use 'apploi' for rebuilds."
