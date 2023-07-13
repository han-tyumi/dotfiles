#!/bin/bash
set -x

# Backup shell configuration files
sudo mv /etc/bashrc /etc/bashrc.backup-before-nix-darwin
sudo mv /etc/zshrc /etc/zshrc.backup-before-nix-darwin

# Add Home Manager channel
# https://nix-community.github.io/home-manager/
nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
nix-channel --update

# Install Nix Darwin
# https://github.com/LnL7/nix-darwin
nix-build https://github.com/LnL7/nix-darwin/archive/master.tar.gz -A installer
./result/bin/darwin-installer
