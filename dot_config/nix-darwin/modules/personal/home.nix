{ config, lib, ... }:

{
  home = {
    sessionPath = [
      "$CARGO_HOME/bin"
      "$HOME/.dotnet/tools"
      "$HOME/.config/v-analyzer/bin"
      "$HOME/roc"
    ];
    sessionVariables = {
      CARGO_HOME = "$HOME/.cargo";
      RUSTUP_HOME = "$HOME/.rustup";
    };

    # Append this identity's signing pubkey to the allowed_signers file (created
    # by shared's gitAllowedSignersInit) so `git log --show-signature` verifies
    # its commits locally. Per-machine key, so read it live.
    activation.gitAllowedSignersPersonal = lib.hm.dag.entryAfter [ "gitAllowedSignersInit" ] ''
      if [ -f "$HOME/.ssh/git_han-tyumi.pub" ]; then
        printf 'mmchamp95@gmail.com namespaces="git" %s\n' \
          "$(cat "$HOME/.ssh/git_han-tyumi.pub")" \
          >> "${config.xdg.configHome}/git/allowed_signers"
      fi
    '';
  };

  programs = {
    git.settings = {
      user = {
        name = "Matt Champagne";
        email = "mmchamp95@gmail.com";
        signingKey = "~/.ssh/git_han-tyumi.pub";
      };
      github.user = "han-tyumi";
      core.sshCommand = "ssh -i ~/.ssh/git_han-tyumi";
    };
  };
}
