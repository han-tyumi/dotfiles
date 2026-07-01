#!/bin/bash

# Install Nix Darwin
# https://github.com/nix-darwin/nix-darwin
if [[ -x /run/current-system/sw/bin/darwin-rebuild ]]; then
  echo "Nix Darwin is already installed."
else
  # The Nix install from the previous script hasn't touched this shell yet, and
  # sudo's secure_path won't find nix either.
  nix=/nix/var/nix/profiles/default/bin/nix

  # The flake's nix-darwin input is the single source of truth for the channel.
  ref="$(sed -n 's|.*"github:nix-darwin/nix-darwin/\([^"]*\)".*|\1|p' "$HOME/.config/nix-darwin/flake.nix")"
  if [[ -z $ref ]]; then
    echo "Could not read the nix-darwin ref from ~/.config/nix-darwin/flake.nix." >&2
    exit 1
  fi

  # nix-darwin's activation refuses to overwrite files it wants to manage.
  echo "Backing up configuration files..."
  for file in /etc/nix/nix.conf /etc/bashrc /etc/zshrc; do
    if [[ -f $file ]]; then
      sudo mv "$file" "$file.backup-before-nix-darwin"
    fi
  done

  # Generate flake.lock as the invoking user so root never owns it. A
  # root-owned lock makes every later user-level `nix flake update` fail with
  # EPERM; --no-write-lock-file below keeps the root rebuild from re-owning it.
  "$nix" --extra-experimental-features 'nix-command flakes' \
    flake lock ~/.config/nix-darwin

  echo "Installing Nix Darwin..."
  sudo "$nix" run --extra-experimental-features 'nix-command flakes' \
    "nix-darwin/$ref#darwin-rebuild" -- switch --flake ~/.config/nix-darwin --no-write-lock-file
fi
