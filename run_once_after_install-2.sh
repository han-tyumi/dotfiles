#!/bin/bash

# Install Nix Darwin
# https://github.com/LnL7/nix-darwin
if [[ -x /run/current-system/sw/bin/darwin-rebuild ]]; then
  echo "Nix Darwin is already installed."
else
  # Backup shell configuration files
  echo "Backing up configuration files..."
  sudo mv /etc/nix/nix.conf /etc/nix/nix.conf.backup-before-nix-darwin
  sudo mv /etc/bashrc /etc/bashrc.backup-before-nix-darwin
  sudo mv /etc/zshrc /etc/zshrc.backup-before-nix-darwin

  echo "Installing Nix Darwin..."
  nix run nix-darwin -- switch --flake ~/.config/nix-darwin
fi
