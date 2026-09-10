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

  snapshotRetentionDays = 7;

  # Take an APFS snapshot and drop the ones past the retention window. Neither
  # tmutil call needs privileges, and no Time Machine destination has to be
  # configured — snapshots taken this way are marked purgeable, so macOS reclaims
  # them under space pressure instead of filling the disk.
  #
  # Absolute paths throughout: launchd does not run this with the interactive
  # PATH, and `date` there would resolve to GNU coreutils, which has no -v.
  #
  # The timestamps are fixed-width, so a lexicographic comparison against the
  # cutoff orders them correctly without parsing.
  apfsSnapshot = pkgs.writeShellScript "apfs-snapshot" ''
    set -u

    /usr/bin/tmutil localsnapshot >/dev/null || exit 0

    cutoff="$(/bin/date -v-${toString snapshotRetentionDays}d +%Y-%m-%d-%H%M%S)"
    /usr/bin/tmutil listlocalsnapshots / 2>/dev/null | while read -r snapshot; do
      case "$snapshot" in
        com.apple.TimeMachine.*.local) ;;
        *) continue ;;
      esac
      stamp="''${snapshot#com.apple.TimeMachine.}"
      stamp="''${stamp%.local}"
      if [[ "$stamp" < "$cutoff" ]]; then
        /usr/bin/tmutil deletelocalsnapshots "$stamp" >/dev/null
      fi
    done
  '';
in

{
  # A rolling hour-granular undo for the whole volume. Same-disk and purgeable, so
  # this is not a backup — it does not survive drive failure and macOS may reclaim
  # it — but it covers the case a backup is slowest at: something deleting files
  # that were never committed or pushed.
  launchd.agents.apfs-snapshot = {
    enable = true;
    config = {
      ProgramArguments = [ "${apfsSnapshot}" ];
      RunAtLoad = true;
      StartInterval = 3600;
      # Snapshots are metadata work, but thinning can touch a lot of blocks.
      LowPriorityIO = true;
      Nice = 5;
      # Nothing is written on success, so this only ever holds failures.
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/apfs-snapshot.log";
    };
  };

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

    # rtk generates its own instruction file (~/.claude/RTK.md), so the copy on
    # disk has to come from the rtk that is installed. Homebrew upgrades rtk
    # earlier in this same activation, so re-running init here keeps the two in
    # step on every switch. --no-patch keeps rtk out of ~/.claude/settings.json:
    # the hook entry there comes from .chezmoitemplates/claude-settings.json,
    # which chezmoi merges into the live file before the rebuild.
    activation.rtkInit = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      export PATH="/opt/homebrew/bin:$PATH"
      if command -v rtk > /dev/null; then
        # A machine with no recorded telemetry consent gets an interactive prompt,
        # and activation has no one to answer it: rtk skips the prompt when stdin
        # is not a terminal.
        run rtk init --global --no-patch < /dev/null \
          || echo "rtk init failed; re-run 'rtk init --global --no-patch' by hand" >&2

        # Buffer rtk's output first so `grep -q`'s early exit can't SIGPIPE rtk
        # under pipefail. Drift warns rather than fails: a stale hook is a source
        # edit to make, not a reason to abort activation, and a failed assignment
        # under errexit would abort it.
        rtk_status=$(rtk init --show < /dev/null 2>&1 || true)
        if ! printf '%s\n' "$rtk_status" | grep -q '^\[ok\] settings.json:'; then
          echo "⚠ RTK hook missing or outdated in ~/.claude/settings.json" >&2
          echo "  Run 'rtk init --show' to see the expected format." >&2
          echo "  Then update .chezmoitemplates/claude-settings.json in the chezmoi source and re-apply." >&2
        fi
      fi
    '';

    # `pkgs.gh-stack` is 0.0.4 on the 26.05 channel against 0.1.0 upstream, and
    # 0.0.4 predates `gh stack merge` and the public Stacks REST API, so the
    # extension comes from its own releases until the channel carries 0.1.0 and
    # this can become `programs.gh.extensions = [ pkgs.gh-stack ]`.
    #
    # `install --force` rather than a list-then-upgrade branch: install is the one
    # subcommand exempt from gh's auth check, and with the extension already at the
    # newest release it is a no-op. Non-fatal, since a flaky network or an
    # unauthenticated gh must not abort activation.
    activation.ghStackExtension = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run ${config.programs.gh.package}/bin/gh extension install --force github/gh-stack || {
        echo "gh extension install --force github/gh-stack failed; re-run it by hand." >&2
        echo "On a name collision or a missing latest version, another extension owns the 'stack' command: 'gh extension remove stack' first." >&2
      }
    '';

    enableNixpkgsReleaseCheck = false;

    # home-manager renders shellAliases into config.nu, which nushell parses before
    # the autoload fragments — so without this a same-named alias from the
    # community set 10-community.nu imports would win. Re-declaring them from the
    # same attrset in a late-sorting fragment keeps one source of truth (and zsh's
    # copy) while making these the last definition nushell sees.
    file."${config.programs.nushell.configDir}/autoload/90-shell-aliases.nu".text = lib.concatLines (
      lib.mapAttrsToList (
        name: command: ''alias "${name}" = ${command}''
      ) config.programs.nushell.shellAliases
    );

    # `broot --print-shell-function nushell` emits a module whose entry point is
    # `main`, so the command it defines is named after the file it lives in. It goes
    # on NU_LIB_DIRS under the stem `br`, and autoload/40-broot.nu imports it.
    file."${config.programs.nushell.configDir}/scripts/br.nu".source = pkgs.runCommand "br.nu" {
      nativeBuildInputs = [ config.programs.broot.package ];
    } "broot --print-shell-function nushell > $out";

    sessionPath = [
      "/opt"
      "$HOME/.local/bin"
    ];
    shellAliases = {
      cat = "bat";
      g = "git";
      gs = "gh stack";
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
    broot = {
      enable = true;

      # home-manager `source`s broot's nushell integration, which defines the stray
      # command `main` and no `br`, so the import is wired by hand instead.
      enableNushellIntegration = false;
    };
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

        # programs.delta wires delta into pager.{diff,log,show,blame}; core.pager
        # extends it to every other paginated command (range-diff, reflog -p,
        # grep). navigate and line-numbers are delta's own knobs, themed by the
        # catppuccin include.
        core.pager = lib.getExe config.programs.delta.package;
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

      # The kickstart config asks for neither host: no *_host_prog, no rplugin, and
      # its plugins are Lua apart from C (treesitter, telescope-fzf-native) and Rust
      # (blink.cmp). false is also the 26.05 default, so raising home.stateVersion
      # stays a no-op here. withPython3 is inert either way — home-manager wraps
      # neovim with wrapRc = false, so the generated python3_host_prog is never
      # sourced — but saying so silences the warning.
      withRuby = false;
      withPython3 = false;
    };
    nix-index = {
      enable = true;

      # The nushell integration installs a command_not_found hook that shells out to
      # nix-locate. Nothing builds the index, so every typo printed a database I/O
      # error ahead of nushell's own message; `nix-locate` stays available by hand.
      enableNushellIntegration = false;
    };
    nushell = {
      enable = true;
      configFile.source = ../../nushell/config.nu;

      # nu rejects a plugin whose nu-plugin crate differs in minor version from its
      # own, and nixpkgs' nu_plugin_highlight trails the nushell it ships — on
      # master too. bat and the built-in nu-highlight cover the ground; the upstream
      # tag matching the packaged nushell is the way back if it is ever wanted.
      plugins = with pkgs.nushellPlugins; [
        query
        skim
      ];
    };
    ripgrep.enable = true;
    starship.enable = true;
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
