{
  pkgs,
  inputs,
  profiles,
  ...
}:

{
  nixpkgs = {
    config.allowUnfree = true;

    # The platform the configuration will be used on.
    hostPlatform = "aarch64-darwin";

    overlays = [
      (final: prev: { nodejs = prev.nodejs_24; })

      # TODO: drop once nix#15638 ships. Darwin Mach-O codesign corruption
      # in cached store paths SIGKILLs direnv's checkPhase. See nixpkgs#507531.
      (final: prev: {
        direnv = prev.direnv.overrideAttrs (_: {
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
      profiles.username
    ];
  };

  homebrew = {
    enable = true;
    taps = [
      "knope-dev/tap"
    ];
    brews = [
      "git-spice"
      "golangci-lint"
      "knope"
      "mas"
      "mise"
      "poppler"
      "rtk"
      "zlib"
      "zstd"
    ];
    casks = [
      "arc"
      "bitwarden"
      "claude"
      "docker-desktop"
      "eqmac"
      "keycastr"
      "postgres-app"
      "raycast"
      "the-unarchiver"
      "transmit"
      "visual-studio-code"
      "zed"
      "zen"
    ];
    masApps = {
      Amphetamine = 937984704;
    };
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "zap";
      extraFlags = [ "--force-cleanup" ];
    };
  };

  users.users.${profiles.username} = {
    name = profiles.username;
    description = "Han-Tyumi";
    home = "/Users/${profiles.username}";
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
      passh
      php
      pkg-config
      shellcheck
      shfmt
      unison-ucm
      github-mcp-server
      wget
    ];
  };

  system = {
    primaryUser = profiles.username;
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
      pkgs.nushell
      pkgs.zsh
    ];
  };

  security.pam.services.sudo_local.touchIdAuth = true;

  programs = {
    bash.enable = false;
    zsh.enable = true;
  };
}
