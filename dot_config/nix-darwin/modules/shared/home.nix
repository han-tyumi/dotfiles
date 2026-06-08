{
  config,
  lib,
  pkgs,
  ...
}:

let
  gitAliasFileName = "gitalias.txt";
  gitAliasFilePath = "gitalias/${gitAliasFileName}";

  # generated from `nix run nixpkgs#nurl https://github.com/catppuccin/delta`
  catppuccinDelta = pkgs.fetchFromGitHub {
    owner = "catppuccin";
    repo = "delta";
    rev = "011516f5d14f66b771b3e716f29c77231e008c74";
    hash = "sha256-lztkxX9O41YossvRzpR7tqxMhDNT1Efy2JvkCwtsiXQ=";
  };
in

{
  home = {
    # darwin.nix points screencapture at this directory; macOS won't create it.
    activation.screenshotsDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run mkdir -p ~/Pictures/Screenshots
    '';

    # Rebuild the git allowed_signers file from scratch; each enabled identity
    # layer appends its own signing pubkey after this (gitAllowedSigners*).
    activation.gitAllowedSignersInit = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "${config.xdg.configHome}/git"
      : > "${config.xdg.configHome}/git/allowed_signers"
    '';

    enableNixpkgsReleaseCheck = false;
    sessionPath = [
      "/opt"
      "$HOME/.local/bin"
    ];
    shellAliases = {
      cat = "bat";
      g = "git";
      gs = "git-spice";
      p = "pnpm";
      y = "yarn";
      znu = "zsh -lc nu";
    };
    stateVersion = "25.11";
  };

  # link gitalias.txt from store
  xdg.configFile = {
    # Kickstart (chezmoi external) owns nvim/init.lua.
    "nvim/init.lua".enable = lib.mkForce false;

    "${gitAliasFilePath}".source =
      # generated from `nix run nixpkgs#nurl https://github.com/GitAlias/gitalias/`
      pkgs.fetchFromGitHub {
        owner = "GitAlias";
        repo = "gitalias";
        rev = "13a84be01a0335ab258ef5c0aefd8dc7fe584e23";
        hash = "sha256-CJh/JMcL42IjHLt5S6h8JqvW8sjGaFj7ZP9nW9l5eBw=";
      }
      + "/${gitAliasFileName}";
  };

  programs = {
    atuin.enable = true;
    bat.enable = true;
    broot.enable = true;
    carapace.enable = true;
    delta = {
      enable = true;
      enableGitIntegration = true;
      options.features = "catppuccin-mocha";
    };
    direnv = {
      enable = true;
      silent = true;
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
    eza.enable = true;
    fd.enable = true;
    fzf.enable = true;
    gh = {
      enable = true;
    };
    git = {
      enable = true;
      lfs.enable = true;
      settings = {
        init = {
          defaultBranch = "main";
        };
        push.autoSetupRemote = true;

        # Sign with the per-identity SSH key set by each layer's user.signingKey;
        # each identity layer drops that key's pubkey into the allowed_signers file.
        gpg.format = "ssh";
        gpg.ssh.allowedSignersFile = "${config.xdg.configHome}/git/allowed_signers";
        commit.gpgsign = true;
        tag.gpgsign = true;
      };
      includes = [
        { path = "${config.xdg.configHome}/${gitAliasFilePath}"; }
        { path = "${catppuccinDelta}/catppuccin.gitconfig"; }
      ];
      ignores = [
        ".claude/*.local.md"
        ".claude/*.local.json"
        ".env.local"
        ".mcp.local.json"
        ".scratch"
        "CLAUDE.local.md"
        "mise.local.toml"
      ];
    };
    intelli-shell.enable = true;
    java = {
      enable = true;
      package = pkgs.temurin-bin-25;
    };
    neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
      vimdiffAlias = true;
    };
    nix-index.enable = true;
    nushell = {
      enable = true;
      configFile.source = ../../nushell/config.nu;
      plugins = with pkgs.nushellPlugins; [
        highlight
        query
        skim
      ];
    };
    ripgrep.enable = true;
    starship = {
      enable = true;
      enableTransience = true;
    };
    tealdeer.enable = true;
    zoxide.enable = true;
    zsh = {
      enable = true;
      # Homebrew's shellenv already comes from darwin.nix environment.extraInit,
      # which nix-darwin sources for every zsh via /etc/zshenv.
      profileExtra = ''
        eval "$(mise activate zsh --shims)"
      '';
    };
  };
}
