{ machine, ... }:

{
  homebrew = {
    brews = [
      "exercism"
      "ferium"
      "golangci-lint"
    ];
    casks = [
      "claude"
      "eqmac"
      "gimp"
      "marginnote"
      "modrinth"
      "moonlight"
      "prismlauncher"
      "private-internet-access"
      "steam"
      "transmit"
      "zoom"
    ];
    masApps = {
      Amphetamine = 937984704;
      iMovie = 408981434;
      "Logic Pro" = 634148309;
      "Steam Link" = 1246969117;
    };
  };

  users.users.${machine.username}.description = "Han-Tyumi";
}
