#!/bin/bash

# Install Homebrew
# https://brew.sh/
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Nix
# https://nixos.org/
bash -c "$(curl -L https://nixos.org/nix/install)"

# Install Hombrew & Nix dependents
bash post_install.sh
