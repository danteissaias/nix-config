{ pkgs, ... }:
{
  system.defaults = {
    menuExtraClock.Show24Hour = true;
    dock.autohide = true;
    dock.show-recents = false;
    dock.persistent-apps = [
      "${pkgs.arc-browser}/Applications/Arc.app"
      "${pkgs.kitty}/Applications/Kitty.app"
      "/System/Applications/Mail.app"
      "${pkgs.spotify}/Applications/Spotify.app"
    ];
    finder.AppleShowAllFiles = true;
    NSGlobalDomain.AppleInterfaceStyle = "Dark";
    NSGlobalDomain.KeyRepeat = 2;
  };
}
