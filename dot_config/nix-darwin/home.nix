{ pkgs, ... }:

let
  private = import ./private.nix;
in

{
  home = {
    sessionVariables = {
      EDITOR = "code --wait";
      DUNE_CACHE = "enabled";
    };
    shellAliases = {
      cat = "bat";
    };
    stateVersion = "23.11";
  };

  programs = {
    atuin.enable = true;
    bash.enable = true;
    bat.enable = true;
    direnv = {
      enable = true;
      nix-direnv.enable = true;
      stdlib = ''
        : "''${XDG_CACHE_HOME:="$HOME/.cache"}"
        declare -A direnv_layout_dirs
        direnv_layout_dir() {
          local hash path
          echo "''${direnv_layout_dirs[$PWD]:=$(
            hash="$(sha1sum - <<<"$PWD" | head -c40)"
            path="''${PWD//[^a-zA-Z0-9]/-}"
            echo "$XDG_CACHE_HOME/direnv/layouts/$hash$path"
          )}"
        }
      '';
    };
    eza = {
      enable = true;
      enableAliases = true;
    };
    fish.enable = true;
    fzf.enable = true;
    gh = {
      enable = true;
    };
    git = {
      enable = true;
      delta.enable = true;
    };
    java = {
      enable = true;
      package = pkgs.temurin-bin-17;
    };
    kitty = {
      enable = true;
      settings = {
        shell = "${pkgs.fish}/bin/fish";
      };
    };
    mpv.enable = true;
    neovim = {
      enable = true;
      viAlias = true;
      vimAlias = true;
      vimdiffAlias = true;
    };
    nnn.enable = true;
    rbw = {
      enable = true;
      settings = {
        email = private.bitwardenEmail;
      };
    };
    ripgrep.enable = true;
    starship.enable = true;
    tealdeer.enable = true;
    vscode.enable = true;
    zellij.enable = true;
    zoxide.enable = true;
    zsh.enable = true;
  };
}
