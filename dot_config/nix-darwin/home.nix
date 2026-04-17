{
  config,
  pkgs,
  ...
}:

let
  private = import ./private.nix;
  gitAliasFileName = "gitalias.txt";
  gitAliasFilePath = "gitalias/${gitAliasFileName}";
  workGitIdentity = {
    user = {
      name = "Matt Champagne";
      email = "matthew.champagne@revvity.com";
    };
    github.user = "chmmpagne";
    core = {
      sshCommand = "ssh -i ~/.ssh/git_chmmpagne";
    };
  };
in

{
  home = {
    enableNixpkgsReleaseCheck = false;
    sessionPath = [
      "/opt"
      "$CARGO_HOME/bin"
      "$HOME/.local/bin"
      "$HOME/.dotnet/tools"
      "$HOME/.config/v-analyzer/bin"
      "$HOME/roc"
    ];
    sessionVariables = {
      DUNE_CACHE = "enabled";
      CARGO_HOME = "$HOME/.cargo";
      RUSTUP_HOME = "$HOME/.rustup";
      GH_TOKEN = private.githubToken;
      GITHUB_PERSONAL_ACCESS_TOKEN = private.githubToken;
    };
    shellAliases = {
      ai = "aichat";
      cat = "bat";
      g = "git";
      p = "pnpm";
      y = "yarn";
      znu = "zsh -lc nu";
    };
    stateVersion = "23.11";
  };

  # link gitalias.txt from store
  xdg.configFile = {
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
    bash.enable = false;
    bat.enable = true;
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
    fish = {
      enable = true;
      interactiveShellInit = ''
        set -g fish_greeting
      '';
      shellInit = ''
        eval "$(/opt/homebrew/bin/brew shellenv)"

        if status is-interactive; and set -q TERM_PROGRAM
          mise activate fish | source
        else
          mise activate fish --shims | source
        end

        source "$CARGO_HOME/env.fish"
      '';
      plugins = [
        {
          name = "macos";
          src = pkgs.fishPlugins.macos.src;
        }
        {
          name = "plugin-git";
          src = pkgs.fishPlugins.plugin-git.src;
        }
        {
          name = "z";
          src = pkgs.fishPlugins.z.src;
        }
      ];
    };
    fzf.enable = true;
    gh = {
      enable = true;
    };
    git = {
      enable = true;
      lfs.enable = true;
      signing.format = null;
      settings = {
        user = {
          name = "Matt Champagne";
          email = "mmchamp95@gmail.com";
        };
        github.user = "han-tyumi";
        core = {
          sshCommand = "ssh -i ~/.ssh/git_han-tyumi";
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
        {
          condition = "gitdir:~/Code/work/";
          contentSuffix = "revvity";
          contents = workGitIdentity;
        }
        {
          condition = "hasconfig:remote.*.url:git@github.com:Revvity/**";
          contentSuffix = "revvity";
          contents = workGitIdentity;
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
    gitui.enable = false;
    java = {
      enable = true;
      package = pkgs.temurin-bin-25;
    };
    lazygit.enable = true;
    neovide.enable = true;
    neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
      vimdiffAlias = true;
      withPython3 = false;
      withRuby = false;
    };
    nix-index.enable = true;
    nnn.enable = true;
    nushell = {
      enable = true;
      configFile.source = ./nushell/config.nu;
      envFile.source = ./nushell/env.nu;
      settings = {
        show_banner = false;
      };
    };
    rbw = {
      enable = true;
      settings = {
        email = private.bitwardenEmail;
        lock_timeout = 21600;
      };
    };
    ripgrep.enable = true;
    starship = {
      enable = true;
      enableTransience = true;
    };
    tealdeer.enable = true;
    zellij.enable = false;
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
