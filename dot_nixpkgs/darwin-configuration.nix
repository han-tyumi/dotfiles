{ pkgs, ... }:

let
  baseUserPackages = with pkgs; [
    chezmoi
    deno
    dotty
    fd
    nil
    nixpkgs-fmt
    nodejs_20
    purescript
    scala-cli
    scalafmt
    shellcheck
    shfmt
    spago
  ];

  nodePackages = with pkgs.nodePackages_latest; [
    graphite-cli
    pnpm
    yarn
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
      "arc"
      "raycast"
      "transmit"
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
      home = {
        sessionVariables = {
          EDITOR = "code";
        };
        shellAliases = {
          cat = "bat";
        };
        stateVersion = "23.11";
      };

      programs = enabledShells // {
        atuin.enable = true;
        bat.enable = true;
        direnv.enable = true;
        exa = {
          enable = true;
          enableAliases = true;
        };
        fzf.enable = true;
        git = {
          enable = true;
          delta.enable = true;
        };
        java = {
          enable = true;
          package = pkgs.temurin-bin-17;
        };
        kitty.enable = true;
        mpv.enable = true;
        neovim = {
          enable = true;
          viAlias = true;
          vimAlias = true;
          vimdiffAlias = true;
        };
        nnn.enable = true;
        ripgrep.enable = true;
        sbt.enable = true;
        starship.enable = true;
        tealdeer.enable = true;
        vscode.enable = true;
        zellij.enable = true;
        zoxide.enable = true;
      };
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
