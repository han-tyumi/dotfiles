#!/bin/bash

# Install Homebrew
# https://brew.sh/
if [[ -x /opt/homebrew/bin/brew ]]; then
  echo "Homebrew is already installed."
else
  echo "Installing Homebrew ..."
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Install Nix
# https://nixos.org/download
# The base installer's profile path; /run/current-system appears only once
# nix-darwin has activated.
if [[ -x /nix/var/nix/profiles/default/bin/nix ]]; then
  echo "Nix is already installed."
else
  echo "Installing Nix ..."
  sh <(curl -L https://nixos.org/nix/install)
fi
