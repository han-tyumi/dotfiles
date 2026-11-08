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

    # shared/darwin.nix force-empties masApps when appStore = false, so these
    # never apply on a machine without a signed-in App Store account.
    masApps = {
      iMovie = 408981434;
      "Logic Pro" = 634148309;
      "Steam Link" = 1246969117;
    };
  };

  users.users.${machine.username}.description = "Han-Tyumi";

  system.defaults.dock = {
    # Grouped by purpose, with the most used apps toward the center.
    persistent-apps = [
      { app = "/System/Applications/Apps.app"; }
      { app = "/System/Applications/Reminders.app"; }
      { app = "/System/Applications/Notes.app"; }
      { app = "/System/Applications/Calendar.app"; }
      { app = "/System/Cryptexes/App/System/Applications/Safari.app"; }
      { app = "/Applications/Ghostty.app"; }
      { app = "/Applications/Zed.app"; }
      { app = "/Applications/Claude.app"; }
      { app = "/System/Applications/Messages.app"; }
      { app = "/System/Applications/Maps.app"; }
      { app = "/Applications/Bitwarden.app"; }
      { app = "/System/Applications/System Settings.app"; }
    ];
    persistent-others = [ "/Users/${machine.username}/Downloads" ];
  };
}
