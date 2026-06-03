{ lib, profiles, ... }:

let
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
  programs.git = {
    # Without the personal profile, the work identity is the global default.
    settings = lib.mkIf (!profiles.personal) workGitIdentity;

    includes = [
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
  };
}
