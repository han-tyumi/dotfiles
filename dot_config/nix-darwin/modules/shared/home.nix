{
  config,
  lib,
  pkgs,
  ...
}:

let
  gitAliasFileName = "gitalias.txt";
  gitAliasFilePath = "gitalias/${gitAliasFileName}";
in

{
  home = {
    enableNixpkgsReleaseCheck = false;
    sessionPath = [
      "/opt"
      "$CARGO_HOME/bin"
      "$HOME/.local/bin"
      "$HOME/.dotnet/tools"
    ];
    sessionVariables = {
      DUNE_CACHE = "enabled";
      CARGO_HOME = "$HOME/.cargo";
      RUSTUP_HOME = "$HOME/.rustup";
    };
    shellAliases = {
      ai = "aichat";
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
    aichat.enable = true;
    atuin.enable = true;
    bat.enable = true;
    broot.enable = true;
    carapace.enable = true;
    delta = {
      enable = true;
      enableGitIntegration = true;
    };
    direnv = {
      enable = true;
      silent = true;
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
        core = {
          # editor = "code --wait";
        };
        init = {
          defaultBranch = "main";
        };
        # sequence = {
        #   editor = "code --wait --add";
        # };
        push.autoSetupRemote = true;
        alias = {
          resetu = "reset-to-upstream";
        };
      };
      includes = [
        { path = "${config.xdg.configHome}/${gitAliasFilePath}"; }

        # Fetch auth for the work overlay clone, needed before the work
        # layer's own git config has ever been applied.
        {
          condition = "hasconfig:remote.*.url:git@github.com:chmmpagne/**";
          contentSuffix = "chmmpagne";
          contents.core.sshCommand = "ssh -i ~/.ssh/git_chmmpagne";
        }
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
    git-cliff.enable = true;
    git-credential-oauth.enable = true;
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
      envExtra = ''
        eval "$(direnv hook zsh)"
      '';
      profileExtra = ''
        eval "$(/opt/homebrew/bin/brew shellenv)"
        eval "$(mise activate zsh --shims)"
      '';
    };
  };
}
