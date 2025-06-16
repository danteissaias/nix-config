{
  pkgs,
  hostname,
  username,
  ...
}:

{
  # Allow authentication with Apple Watch with closed lid
  environment.systemPackages = [ pkgs.pam-watchid ];
  security.pam.services.sudo_local.touchIdAuth = true;
  security.pam.services.sudo_local.watchIdAuth = true;

  networking.computerName = "Dante's MacBook Pro";
  networking.hostName = "${hostname}";
  networking.knownNetworkServices = [ "Wi-Fi" ];
  networking.dns = [
    "1.1.1.1" # Cloudflare
    "8.8.8.8" # Google
  ];

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

  # system.activationScripts.postUserActivation.text = ''
  #   # Following line should allow us to avoid a logout/login cycle
  #   /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
  # '';
}
