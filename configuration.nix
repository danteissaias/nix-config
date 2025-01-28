{
  pkgs,
  username,
  lib,
  inputs,
  ...
}:

{
  imports = [ ./system.nix ];

  environment.shells = [ pkgs.fish ];

  services.nix-daemon.enable = true;

  nix.optimise.automatic = true;

  nix.settings = {
    experimental-features = "nix-command flakes";
    use-xdg-base-directories = true;
  };

  programs.fish.enable = true;

  system = {
    stateVersion = 5;
    configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;
  };

  users.users.${username} = {
    name = username;
    home = "/Users/${username}";
    isHidden = false;
    shell = pkgs.fish;
  };

  nixpkgs = {
    hostPlatform = "aarch64-darwin";
    config.allowUnfree = true;
    overlays = [ inputs.fenix.overlays.default ];
  };

  # security.pam.enableSudoTouchIdAuth = true;

  environment.systemPackages = [ pkgs.pam-watchid ];

  environment.etc."pam.d/sudo_local" = {
    text = ''
      auth       sufficient     ${lib.getLib pkgs.pam-watchid}/lib/pam_watchid.so
      auth       sufficient     pam_tid.so
    '';
  };

  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";
    casks = [
      "1password"
      "spotify"
      "arc"
      "raycast"
      "slack"
      "docker"
      "postgres-unofficial"
      "postico"
      "ghostty@tip"
      "linear-linear"
    ];
  };

  # Hack: https://github.com/ghostty-org/ghostty/discussions/2832
  environment.variables.XDG_DATA_DIRS = [ "$GHOSTTY_SHELL_INTEGRATION_XDG_DIR" ];
  environment.systemPath = [ "/Applications/Ghostty.app/Contents/MacOS/" ];
}
