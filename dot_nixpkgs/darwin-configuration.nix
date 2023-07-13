{ pkgs, ... }:

let
  baseUserPackages = with pkgs; [
    git
    fish
    nil
    nixpkgs-fmt
    shellcheck
    shfmt
    chezmoi
    nodejs_20
    deno
    purescript
    spago
    dotty
    scala-cli
    sbt
    scalafmt
  ] ++ nodePackages;

  nodePackages = with pkgs.nodePackages_latest; [
    yarn
    pnpm
  ];

  userPackages = baseUserPackages ++ nodePackages;

  enabledShells = {
    bash.enable = true;
    zsh.enable = true;
    fish.enable = true;
  };
in

{
  imports = [ <home-manager/nix-darwin> ];

  nixpkgs.config.allowUnfree = true;
  services.nix-daemon.enable = true;
  nix.package = pkgs.nix;

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

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.han-tyumi = { ... }: {
      home.stateVersion = "23.11";
      programs = enabledShells;
    };
  };

  system = {
    defaults = {
      NSGlobalDomain = {
        AppleShowAllFiles = true;
        AppleInterfaceStyle = "Dark";
      };
      finder.FXPreferredViewStyle = "Nlsv";
    };

    stateVersion = 4;
  };

  programs = enabledShells;
}
