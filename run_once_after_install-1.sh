#!/bin/bash
set -x

# Install Homebrew
# https://brew.sh/
echo "Installing Homebrew..."
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Nix
# https://nixos.org/
echo "Installing Nix..."
bash -c "$(curl -L https://nixos.org/nix/install)"
