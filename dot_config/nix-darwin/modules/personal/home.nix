_:

let
  # private.nix is layer-gated and absent on machines without the personal
  # layer (and in bare checkouts), where only the eval fixtures import this
  # module; fall back to a stub so they still evaluate.
  private =
    if builtins.pathExists ../../private.nix then
      import ../../private.nix
    else
      {
        bitwardenEmail = "";
        githubToken = "";
      };
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
