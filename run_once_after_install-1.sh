#!/bin/bash

# Install Homebrew
# https://brew.sh/
if [[ -x /opt/homebrew/bin/brew ]]; then
  echo "Homebrew is already installed."
else
  echo "Installing Homebrew..."
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Install Nix
# https://nixos.org/

if [[ -x /run/current-system/sw/bin/nix ]]; then
  echo "Nix is already installed."
else
  echo "Installing Nix..."
  bash -c "$(curl -L https://nixos.org/nix/install)"
fi
