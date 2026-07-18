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

    # Populate the init.templateDir exclude that seeds new repos with .scratch/.
    # Written as a plain file rather than an xdg.configFile symlink: git copies a
    # symlinked template entry verbatim, so a store symlink would leave every repo
    # pointing at a path that dangles on the next garbage collection.
    activation.gitInitTemplate = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "${config.xdg.configHome}/git/template/info"
      printf '.scratch/\n' > "${config.xdg.configHome}/git/template/info/exclude"
    '';

    # Homebrew installs agent-browser earlier in this same activation, so its
    # daemon's Chrome for Testing build is fetched here rather than on a later
    # apply. The download is idempotent (skipped when already present) and
    # non-fatal so a flaky network can't block activation; the brew's node
    # dependency also resolves from /opt/homebrew/bin.
    activation.agentBrowserChrome = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      export PATH="/opt/homebrew/bin:$PATH"
      if command -v agent-browser > /dev/null; then
        run agent-browser install \
          || echo "agent-browser install failed; run it manually to fetch Chrome for Testing" >&2
      fi
    '';

    # Make Zed the default app for source files. Zed's bundle registers a fixed
    # extension list but not public.source-code, and LaunchServices resolves the
    # most specific UTI, so both the broad UTIs and a per-extension long tail are
    # set. Folders are left out so Finder still opens them (use `zed .` instead).
    # Each call is non-fatal so a single unmapped type can't block activation.
    activation.zedDefaultEditor =
      let
        zedBundleId = "dev.zed.Zed";
        duti = "${pkgs.duti}/bin/duti";
        utis = [
          "public.plain-text"
          "public.utf8-plain-text"
          "public.text"
          "public.source-code"
          "public.shell-script"
          "public.json"
          "public.yaml"
          "public.xml"
          "net.daringfireball.markdown"
        ];
        extensions = [
          "js" "jsx" "mjs" "cjs" "ts" "tsx" "mts" "cts"
          "json" "jsonc" "json5" "py" "rs" "go" "rb" "java" "kt"
          "c" "h" "cc" "cpp" "hpp" "cs" "php" "lua"
          "sh" "bash" "zsh" "nu" "toml" "yaml" "yml"
          "md" "markdown" "mdx" "css" "scss" "sass" "less"
          "html" "htm" "xml" "svg" "vue" "svelte" "astro"
          "nix" "sql" "graphql" "gql" "swift" "dart"
          "ex" "exs" "hs" "clj" "vim" "conf" "ini" "env"
          "gleam" "roc" "v" "zig" "tf" "hcl" "proto"
        ];
        setType = type: ''run ${duti} -s ${zedBundleId} ${type} all || echo "duti: could not set ${type}" >&2'';
        setExtension = ext: setType ".${ext}";
      in
      lib.hm.dag.entryAfter [ "writeBoundary" ] (
        lib.concatStringsSep "\n" ((map setType utis) ++ (map setExtension extensions))
      );

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

          # Seed every new/cloned repo's .git/info/exclude from this template
          # (populated by the gitInitTemplate activation). Keeps tree walkers
          # that ignore the global excludesFile — e.g. Biome — out of .scratch/.
          templateDir = "${config.xdg.configHome}/git/template";
        };
        push.autoSetupRemote = true;

        # Rebase local commits on pull instead of merging or nagging.
        pull.rebase = true;

        # Replay recorded conflict resolutions across a branch's repeated rebases.
        rerere.enabled = true;
        rerere.autoUpdate = true;

        rebase.autoStash = true;
        rebase.updateRefs = true;
        fetch.prune = true;

        merge.conflictStyle = "zdiff3";
        diff.algorithm = "histogram";
        diff.colorMoved = "default";
        diff.mnemonicPrefix = true;

        # delta is the pager (catppuccin include); add file navigation + line numbers.
        delta.navigate = true;
        delta.line-numbers = true;

        # Safe force-push for the rebase-heavy workflow.
        alias.pushf = "push --force-with-lease --force-if-includes";

        # Fail loudly instead of guessing an identity from the host/gecos when no
        # layer or includeIf condition has set one.
        user.useConfigOnly = true;

        # ghq clones into ~/Developer/<host>/<org>/<repo>.
        ghq.root = "~/Developer";

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
