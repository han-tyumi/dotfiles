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
      (_: prev: { nodejs = prev.nodejs_24; })

      # TODO: drop once nix#15638 ships. Darwin Mach-O codesign corruption
      # in cached store paths SIGKILLs direnv's checkPhase. See nixpkgs#507531.
      (_: prev: {
        direnv = prev.direnv.overrideAttrs (_: {
          doCheck = false;
        });
      })
    ];
  };

  nix = {
    settings = {
      # Necessary for using flakes on this system.
      experimental-features = "nix-command flakes auto-allocate-uids";
      extra-nix-path = "nixpkgs=flake:nixpkgs";

      download-buffer-size = 512 * 1024 * 1024;

      trusted-users = [
        "root"
        machine.username
      ];
    };

    # Prune old system and per-user generations, then collect garbage;
    # rollback reaches back 30 days.
    gc = {
      automatic = true;
      interval = {
        Weekday = 0;
        Hour = 3;
        Minute = 0;
      };
      options = "--delete-older-than 30d";
    };

    # Hard-link identical store files.
    optimise.automatic = true;
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

      # The cleanup option emits bundle's deprecated --cleanup switch, so
      # request zap cleanup directly; --force-cleanup also skips the
      # confirmation prompt activation can't answer.
      extraFlags = [ "--force-cleanup" "--zap" ];
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
      yubikey-manager
    ];
  };

  system = {
    primaryUser = machine.username;
    defaults = {
      NSGlobalDomain = {
        AppleShowAllExtensions = true;
        AppleShowAllFiles = true;

        # Auto appearance lives in its own flag and overrides Dark when a
        # machine was set up with it; pin it off so Dark always wins.
        AppleInterfaceStyle = "Dark";
        AppleInterfaceStyleSwitchesAutomatically = false;
        AppleScrollerPagingBehavior = true;
        AppleShowScrollBars = "Automatic";

        # Full keyboard access: Tab moves focus through all controls.
        AppleKeyboardUIMode = 2;
        "com.apple.keyboard.fnState" = true;
      };
      dock = {
        autohide = true;

        # Small at rest (quieter accidental reveals), subtle growth on hover.
        tilesize = 48;
        magnification = true;
        largesize = 64;

        # Keep Spaces in fixed order instead of most-recently-used.
        mru-spaces = false;
      };
      finder = {
        FXPreferredViewStyle = "Nlsv";
        ShowPathbar = true;
        ShowStatusBar = true;
        FXRemoveOldTrashItems = true;
      };

      # The directory must exist or macOS falls back to the Desktop;
      # home.nix creates it.
      screencapture.location = "/Users/${machine.username}/Pictures/Screenshots";

      CustomUserPreferences = {
        # The profile these keys select carries binary font/color blobs nix
        # can't express, so the terminal-profile run script imports it from
        # a tracked file; the plain keys live here, re-asserted on every
        # activation since Terminal rewrites its prefs on quit.
        "com.apple.Terminal" = {
          "Default Window Settings" = "catppuccin-mocha";
          "Startup Window Settings" = "catppuccin-mocha";

          # Nushell is the interactive shell; the login zsh assembles the
          # nix/Homebrew environment it inherits. (zsh stays the login
          # shell — nushell isn't POSIX.)
          Shell = "/bin/zsh -lc nu";
        };
      };
    };

    # nix-darwin only restarts the Dock after writing defaults; flush the rest
    # into the running session instead of waiting for a re-login.
    activationScripts.postActivation.text = ''
      sudo -u ${machine.username} /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
    '';

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

  fonts.packages = with pkgs; [
    # Iosevka is the editor face, with Slab kept as an alternate;
    # Aile and Etoile are the quasi-proportional siblings for prose.
    iosevka-bin
    (iosevka-bin.override { variant = "Slab"; })
    (iosevka-bin.override { variant = "Aile"; })
    (iosevka-bin.override { variant = "Etoile"; })

    # Icon glyphs as a fallback font, so the editor face needs no patching.
    nerd-fonts.symbols-only
  ];

  security.pam.services.sudo_local.touchIdAuth = true;

  programs = {
    bash.enable = false;
    zsh.enable = true;
  };
}
