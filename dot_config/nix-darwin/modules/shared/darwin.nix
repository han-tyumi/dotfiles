{
  lib,
  pkgs,
  inputs,
  machine,
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
      machine.username
    ];
  };

  # Match the machine's actual nixbld group ID (varies by Nix installer era).
  ids.gids.nixbld = machine.nixbldGid;

  homebrew = {
    enable = true;
    brews = [
      "git-spice"
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
      "docker-desktop"
      "keepingyouawake"
      "postgres-app"
      "raycast"
      "the-unarchiver"
      "visual-studio-code"
      "zed"
      "zen"
    ];
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "zap";
      extraFlags = [ "--force-cleanup" ];
    };

    # An unsigned mas hangs activation waiting on the sign-in dialog, so
    # machines without an App Store account drop masApps from every layer.
    masApps = lib.mkIf (!machine.appStore) (lib.mkForce { });
  };

  users.users.${machine.username} = {
    name = machine.username;
    home = "/Users/${machine.username}";
    shell = pkgs.zsh;
    packages = with pkgs; [
      act
      age
      comma
      coreutils
      chezmoi
      cmake
      ffmpeg
      fontforge
      gnupg
      graphviz
      lua51Packages.lua
      lua51Packages.luarocks
      lua-language-server
      nixd
      nixfmt
      pkg-config
      shellcheck
      shfmt
      github-mcp-server
      wget
    ];
  };

  system = {
    primaryUser = machine.username;
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
