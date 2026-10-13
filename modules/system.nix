{
  pkgs,
  username,
  ...
}:

let
  reload-scroll-direction = pkgs.callPackage ../pkgs/reload-scroll-direction.nix { };
  reload-tap-to-click = pkgs.callPackage ../pkgs/reload-tap-to-click.nix { };
in

{
  # Allow authentication with Apple Watch with closed lid
  # environment.systemPackages = [ pkgs.pam-watchid ];
  # security.pam.services.sudo_local.watchIdAuth = true;
  security.pam.services.sudo_local.touchIdAuth = true;

  networking.knownNetworkServices = [ "Wi-Fi" ];

  system.primaryUser = "${username}";

  system.defaults = {
    menuExtraClock.Show24Hour = true;
    dock.autohide = true;
    dock.show-recents = false;
    dock.persistent-apps = [
      "/Applications/Dia.app"
      "/Applications/Rex Beta.app"
      "/System/Applications/Mail.app"
      "/Applications/Spotify.app"
    ];
    finder.AppleShowAllFiles = true;
    trackpad.Clicking = true; # tap to click
    NSGlobalDomain."com.apple.mouse.tapBehavior" = 1; # tap to click (per-user)
    NSGlobalDomain.AppleInterfaceStyle = "Dark";
    NSGlobalDomain.InitialKeyRepeat = 15;
    NSGlobalDomain.KeyRepeat = 1;
    NSGlobalDomain."com.apple.swipescrolldirection" = false;
    ".GlobalPreferences"."com.apple.mouse.scaling" = 1.5;
  };

  system.activationScripts.postActivation.text = ''
    # Keep the per-host tap-to-click value in sync (used at the login window).
    /usr/bin/sudo -u ${username} /usr/bin/defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

    # Following line should allow us to avoid a logout/login cycle
    /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
    # com.apple.swipescrolldirection doesn't seem to apply without a logout/login cycle, so we
    # have a small script which uses a private API to re-apply the setting.
    ${reload-scroll-direction}/bin/reload-scroll-direction
    # Tap to click does not apply live on switch either; re-apply it through the
    # private MTTGestureBackEnd backend, same idea as the scroll tool above.
    # Unlike the scroll tool, this backend must run inside the user's GUI login
    # session to reach the WindowServer, so launch it with `launchctl asuser`
    # (activation runs as root, detached from that session).
    tapClickUid=$(/usr/bin/id -u ${username})
    /bin/launchctl asuser "$tapClickUid" ${reload-tap-to-click}/bin/reload-tap-to-click 1
    # Disable Spotlight indexing.
    /usr/bin/mdutil -a -i off || true
  '';
}
