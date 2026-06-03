{ pkgs, profiles, ... }:

{
  homebrew.casks = [
    "microsoft-excel"
    "microsoft-teams"
  ];

  users.users.${profiles.username}.packages = with pkgs; [
    openconnect
    vpn-slice
  ];
}
