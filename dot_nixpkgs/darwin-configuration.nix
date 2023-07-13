let
  enabledShells = {
    bash.enable = true;
    zsh.enable = true;
    fish.enable = true;
  };
in
{ pkgs, ... }: {
  imports = [ <home-manager/nix-darwin> ];

  system.defaults = {
    NSGlobalDomain = {
      AppleShowAllFiles = true;
      AppleInterfaceStyle = "Dark";
    };
    finder.FXPreferredViewStyle = "Nlsv";
  };

  nixpkgs.config.allowUnfree = true;
  services.nix-daemon.enable = true;
  nix.package = pkgs.nix;

  environment.systemPackages = [
    pkgs.git
  ];

  homebrew = {
    enable = true;

    casks = [
      "visual-studio-code"
      "kitty"
      "raycast"
      "transmit"
      "arc"
      "utm"
    ];

    global = {
      autoUpdate = false;
    };

    onActivation = {
      cleanup = "zap";
    };
  };

  users.users.han-tyumi = {
    name = "han-tyumi";
    description = "Han-Tyumi";
    home = "/Users/han-tyumi";
    shell = pkgs.fish;
    packages = [
      pkgs.chezmoi
      pkgs.fish
      pkgs.nil
      pkgs.nixpkgs-fmt
      pkgs.shellcheck
      pkgs.shfmt
    ];
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.han-tyumi = { ... }: {
      programs = enabledShells;
      home.stateVersion = "23.11";
    };
  };

  programs = enabledShells;

  system.stateVersion = 4;
}
