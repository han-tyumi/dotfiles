{ pkgs, inputs, ... }:

{
  nixpkgs = {
    config.allowUnfree = true;

    # The platform the configuration will be used on.
    hostPlatform = "aarch64-darwin";

    overlays = [
      (final: prev: { nodejs = prev.nodejs_22; })
      # Skip nushell tests - they fail on macOS due to sandbox permission issues
      (final: prev: {
        nushell = prev.nushell.overrideAttrs (old: {
          doCheck = false;
        });
      })
    ];
  };

  nix.settings = {
    # Necessary for using flakes on this system.
    experimental-features = "nix-command flakes auto-allocate-uids";
    extra-nix-path = "nixpkgs=flake:nixpkgs";

    download-buffer-size = 512 * 1024 * 1024;

    keep-derivations = true;
    keep-outputs = true;

    trusted-users = [
      "root"
      "han-tyumi"
    ];
  };

  homebrew = {
    enable = true;
    taps = [
      "pantsbuild/tap"
      "knope-dev/tap"
    ];
    brews = [
      "exercism"
      "ferium"
      "golangci-lint"
      "knope"
      "mas"
      "mise"
      "poppler"
      "rtk"
      "rustup"
      "zlib"
      "zstd"
    ];
    casks = [
      "arc"
      "bitwarden"
      "claude"
      "docker-desktop"
      "eqmac"
      "firefox"
      "gimp"
      "jetbrains-toolbox"
      "keycastr"
      "kitty"
      "marginnote"
      "microsoft-excel"
      "microsoft-teams"
      "modrinth"
      "moonlight"
      "pants"
      "postgres-app"
      "prismlauncher"
      "private-internet-access"
      "qmk-toolbox"
      "raycast"
      "steam"
      "the-unarchiver"
      "transmit"
      "via"
      "vip-access"
      "visual-studio-code"
      "whatsapp"
      "xmind"
      "zed"
      "zen"
      "zoom"
    ];
    masApps = {
      Amphetamine = 937984704;
      iMovie = 408981434;
      "Logic Pro" = 634148309;
    };
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "zap";
    };
  };

  users.users.han-tyumi = {
    name = "han-tyumi";
    description = "Han-Tyumi";
    home = "/Users/han-tyumi";
    shell = pkgs.zsh;
    packages = with pkgs; [
      act
      age
      comma
      coreutils
      chezmoi
      cmake
      devenv
      ejson
      ffmpeg
      fontforge
      gnupg
      graphviz
      lua51Packages.lua
      lua51Packages.luarocks
      lua-language-server
      nix-health
      nixd
      nixfmt
      nurl
      openconnect
      passh
      php
      pkg-config
      shellcheck
      shfmt
      unison-ucm
      github-mcp-server
      vpn-slice
      wget
    ];
  };

  system = {
    primaryUser = "han-tyumi";
    defaults = {
      NSGlobalDomain = {
        AppleShowAllFiles = true;
        AppleInterfaceStyle = "Dark";
        AppleScrollerPagingBehavior = true;
        AppleShowScrollBars = "Automatic";
        "com.apple.keyboard.fnState" = true;
      };
      finder.FXPreferredViewStyle = "Nlsv";
    };

    # Set Git commit hash for darwin-version.
    configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;

    # Used for backwards compatibility, please read the changelog before changing.
    # $ darwin-rebuild changelog
    stateVersion = 4;
  };

  environment = {
    etc = {
      "sudoers.d/nix-darwin".text = ''
        Defaults timestamp_timeout=360
      '';
    };

    extraInit = ''
      eval "$(/opt/homebrew/bin/brew shellenv)"
    '';

    shells = [
      pkgs.bashInteractive
      pkgs.fish
      pkgs.nushell
      pkgs.zsh
    ];
  };

  security.pam.services.sudo_local.touchIdAuth = true;

  programs = {
    bash.enable = false;
    zsh.enable = true;
    fish = {
      enable = true;
      # nix-daemon.fish only adds ~/.nix-profile/bin and /nix/var/nix/profiles/default/bin.
      # Add the remaining nix-darwin profile paths that set-environment provides for zsh/bash.
      shellInit = ''
        fish_add_path --path /run/current-system/sw/bin
        fish_add_path --path /etc/profiles/per-user/$USER/bin
      '';
    };
  };
}
