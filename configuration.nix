{
  pkgs,
  username,
  inputs,
  ...
}:

{
  imports = [ ./system.nix ];

  environment.shells = [ pkgs.fish ];

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
  };

  # Allow authentication with Apple Watch with closed lid
  environment.systemPackages = [ pkgs.pam-watchid ];
  security.pam.services.sudo_local.touchIdAuth = true;
  security.pam.services.sudo_local.watchIdAuth = true;

  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";
    casks = [
      "1password"
      "spotify"
      "arc"
      "firefox"
      "raycast"
      "slack"
      "docker"
      "postgres-unofficial"
      "postico"
      "ghostty@tip"
      "linear-linear"
      "visual-studio-code"
    ];
  };

  # Hack: https://github.com/ghostty-org/ghostty/discussions/2832
  environment.variables.XDG_DATA_DIRS = [ "$GHOSTTY_SHELL_INTEGRATION_XDG_DIR" ];
  environment.systemPath = [ "/Applications/Ghostty.app/Contents/MacOS/" ];
}
