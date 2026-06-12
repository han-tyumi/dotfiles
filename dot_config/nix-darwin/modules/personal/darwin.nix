{ machine, ... }:

{
  homebrew = {
    brews = [
      "exercism"
      "ferium"
      "golangci-lint"
    ];
    casks = [
      # Browser trials for the eventual Arc exit; a winner graduates to
      # shared, the rest get dropped (zap cleanup uninstalls them).
      "orion"
      "vivaldi"

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

    # shared/darwin.nix force-empties masApps when appStore = false, so these
    # never apply on a machine without a signed-in App Store account.
    masApps = {
      iMovie = 408981434;
      "Logic Pro" = 634148309;
      "Steam Link" = 1246969117;
    };
  };

  users.users.${machine.username}.description = "Han-Tyumi";
}
