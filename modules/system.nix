{
  pkgs,
  username,
  ...
}:

{
  # Allow authentication with Apple Watch with closed lid
  environment.systemPackages = [ pkgs.pam-watchid ];
  security.pam.services.sudo_local.touchIdAuth = true;
  security.pam.services.sudo_local.watchIdAuth = true;

  networking.knownNetworkServices = [ "Wi-Fi" ];

  system.primaryUser = "${username}";

  system.defaults = {
    menuExtraClock.Show24Hour = true;
    dock.autohide = true;
    dock.show-recents = false;
    dock.persistent-apps = [
      "/Applications/Dia.app"
      "/Applications/Ghostty.app"
      "/System/Applications/Mail.app"
      "/Applications/Spotify.app"
    ];
    finder.AppleShowAllFiles = true;
    NSGlobalDomain.AppleInterfaceStyle = "Dark";
    NSGlobalDomain.InitialKeyRepeat = 15;
    NSGlobalDomain.KeyRepeat = 1;
    NSGlobalDomain."com.apple.swipescrolldirection" = false;
    ".GlobalPreferences"."com.apple.mouse.scaling" = 1.5;
  };

  # system.activationScripts.postActivation.text = ''
  #   # Following line should allow us to avoid a logout/login cycle
  #   /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
  # '';
}
