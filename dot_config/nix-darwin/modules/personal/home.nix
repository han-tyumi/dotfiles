_:

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
  };
}
