#!/bin/bash

# Add Home Manager channel
# https://nix-community.github.io/home-manager/
if nix-channel --list | grep -q "home-manager "; then
  echo "Home Manager channel has already been added."
else
  echo "Adding Home Manager channel..."
  nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
  nix-channel --update
fi

# Install Nix Darwin
# https://github.com/LnL7/nix-darwin
if [[ -x /run/current-system/sw/bin/darwin-rebuild ]]; then
  echo "Nix Darwin is already installed."
else
  # Backup shell configuration files
  echo "Backing up shell configuration files..."
  sudo mv /etc/bashrc /etc/bashrc.backup-before-nix-darwin
  sudo mv /etc/zshrc /etc/zshrc.backup-before-nix-darwin

  echo "Installing Nix Darwin..."
  nix-build https://github.com/LnL7/nix-darwin/archive/master.tar.gz -A installer
  ./result/bin/darwin-installer
fi
