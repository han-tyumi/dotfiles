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
      "agent-browser"
      "git-spice"
      "mas"
      "mise"
      "poppler"
      "rtk"
      "zlib"
      "zstd"
    ];
    casks = [
      "bitwarden"
      "docker-desktop"
      "ghostty"
      "keepingyouawake"

      # Blocks keyboard + Touch Bar input (trackpad stays live) so the laptop
      # can be wiped down without stray keystrokes; quit the app to re-enable.
      "keyboardcleantool"
      "postgres-app"
      "raycast"

      # GUI for orchestrating parallel Claude Code sessions in per-worktree
      # workspaces with per-session diff review.
      "conductor"
      "the-unarchiver"
      "vivaldi"
      "zed"
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

        # Folders before files when sorting by name.
        _FXSortFoldersFirst = true;

        # Search the current folder rather than the whole Mac by default.
        FXDefaultSearchScope = "SCcf";

        # New Finder windows open to the home folder.
        NewWindowTarget = "Home";
      };

      # The directory must exist or macOS falls back to the Desktop;
      # home.nix creates it.
      screencapture.location = "/Users/${machine.username}/Pictures/Screenshots";

      CustomUserPreferences = {
        # The profile these keys select carries binary font/color blobs that
        # attrs can't express, so postActivation imports its plist wholesale;
        # everything is re-asserted on every activation since Terminal
        # rewrites its prefs on quit.
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

    activationScripts.postActivation.text = ''
      # Merge the tracked Terminal.app profile (catppuccin-mocha colors,
      # PragmataPro Mono font). Quit Terminal before rebuilding when
      # iterating on it, and capture in-app tweaks back into the source with:
      #   defaults export com.apple.Terminal - \
      #     | plutil -extract 'Window Settings.catppuccin-mocha' xml1 -o - - \
      #     > "$(chezmoi source-path)/dot_config/nix-darwin/modules/shared/catppuccin-mocha.terminal"
      sudo -u ${machine.username} defaults write com.apple.Terminal "Window Settings" -dict-add catppuccin-mocha "$(cat ${./catppuccin-mocha.terminal})"

      # Restore the desktop wallpaper config (Shuffle Landscape aerials, every
      # 12 hours). macOS has no defaults key or nix-darwin option for this; the
      # state lives in an undocumented per-user plist that references built-in
      # aerial asset IDs present on every Mac, so the captured file replays
      # cleanly on the same macOS major version. Recapture after changing it in
      # System Settings with:
      #   cp ~/Library/Application\ Support/com.apple.wallpaper/Store/Index.plist \
      #     "$(chezmoi source-path)/dot_config/nix-darwin/modules/shared/wallpaper-shuffle.plist"
      wallpaper_store="/Users/${machine.username}/Library/Application Support/com.apple.wallpaper/Store"
      sudo -u ${machine.username} mkdir -p "$wallpaper_store"
      sudo -u ${machine.username} cp ${./wallpaper-shuffle.plist} "$wallpaper_store/Index.plist"
      sudo -u ${machine.username} killall WallpaperAgent 2>/dev/null || true

      # nix-darwin only restarts the Dock after writing defaults; flush the
      # rest into the running session instead of waiting for a re-login.
      sudo -u ${machine.username} /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u

      # Restart Finder so the preferred-view-style and other finder defaults
      # take effect now rather than at next login. (This sets the default for
      # folders without a saved per-folder view; folders that already have a
      # .DS_Store keep their own view.)
      sudo -u ${machine.username} killall Finder 2>/dev/null || true
    '';

    # Set Git commit hash for darwin-version.
    configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;

    # Used for backwards compatibility, please read the changelog before changing.
    # $ darwin-rebuild changelog
    stateVersion = 4;
  };

  environment = {
    # Default every shell to a UTF-8 locale. With LANG unset, pbcopy and other
    # locale-sensitive tools decode piped bytes as legacy Mac Roman, mangling
    # UTF-8 (em-dashes, curly quotes, emoji). LANG alone covers every LC_*
    # category; a forcible LC_ALL would stomp individually-set ones.
    variables.LANG = "en_US.UTF-8";

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

  # The editor and terminal face is PragmataPro, which is licensed per
  # machine and therefore installed by hand into ~/Library/Fonts — never
  # through the store or the repo. Configs list fallbacks so machines
  # without it degrade gracefully; the prose companion (Georgia) ships
  # with macOS.
  fonts.packages = with pkgs; [
    # Icon glyphs as a fallback font, so the editor face needs no patching.
    nerd-fonts.symbols-only
  ];

  security.pam.services.sudo_local.touchIdAuth = true;

  programs = {
    bash.enable = false;
    zsh.enable = true;
  };
}
