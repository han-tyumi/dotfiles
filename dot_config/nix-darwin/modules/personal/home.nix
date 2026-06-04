{ ... }:

let
  private = import ../../private.nix;
in

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
      GH_TOKEN = private.githubToken;
      GITHUB_PERSONAL_ACCESS_TOKEN = private.githubToken;
    };
  };

  programs = {
    git.settings = {
      user = {
        name = "Matt Champagne";
        email = "mmchamp95@gmail.com";
      };
      github.user = "han-tyumi";
      core.sshCommand = "ssh -i ~/.ssh/git_han-tyumi";
    };

    rbw = {
      enable = true;
      settings = {
        email = private.bitwardenEmail;
        lock_timeout = 21600;
      };
    };
  };
}
