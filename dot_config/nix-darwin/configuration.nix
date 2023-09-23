{ pkgs, inputs, ... }:

let
  basePackages = with pkgs; [
    age
    coreutils
    chezmoi
    deno
    fd
    inputs.fh.packages.aarch64-darwin.default
    inputs.flake-checker.packages.aarch64-darwin.default
    nil
    nixpkgs-fmt
    nodejs_20
    openconnect
    php
    shellcheck
    shfmt
    vpn-slice
  ];

  nodePackages = with pkgs.nodePackages_latest; [
    degit
    graphite-cli
    pnpm
    yarn
  ];

  userPackages = basePackages ++ nodePackages;
in

{
  nixpkgs = {
    config.allowUnfree = true;

    # The platform the configuration will be used on.
    hostPlatform = "aarch64-darwin";
  };

  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;

  nix.settings = {
    # Necessary for using flakes on this system.
    experimental-features = "nix-command flakes auto-allocate-uids";
    extra-nix-path = "nixpkgs=flake:nixpkgs";

    keep-derivations = true;
    keep-outputs = true;
  };

  homebrew = {
    enable = true;
    casks = [
      "arc"
      "marginnote"
      "moonlight"
      "qmk-toolbox"
      "raycast"
      "steam"
      "transmit"
      "via"
      "zoom"
    ];
    masApps = {
      Amphetamine = 937984704;
      "Logic Pro" = 634148309;
    };
    global.autoUpdate = false;
    onActivation.cleanup = "zap";
  };

  users.users.han-tyumi = {
    name = "han-tyumi";
    description = "Han-Tyumi";
    home = "/Users/han-tyumi";
    shell = pkgs.fish;
    packages = userPackages;
  };

  system = {
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

  programs = {
    bash.enable = true;
    zsh.enable = true;
    fish.enable = true;
  };
}
