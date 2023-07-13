#!/bin/bash

# Install Nix Darwin
# https://github.com/LnL7/nix-darwin
nix-build https://github.com/LnL7/nix-darwin/archive/master.tar.gz -A installer
./result/bin/darwin-installer

# Add Home Manager channel
# https://nix-community.github.io/home-manager/
nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
nix-channel --update
