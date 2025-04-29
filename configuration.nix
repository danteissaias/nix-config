{
  pkgs,
  username,
  inputs,
  hostname,
  config,
  ...
}:

{
  imports = [ ./system.nix ];

  nix.optimise.automatic = true;

  nix.settings = {
    experimental-features = "nix-command flakes";
    use-xdg-base-directories = true;

    # Recommended when using `direnv` etc.
    keep-derivations = true;
    keep-outputs = true;
  };

  # Don't need channels since I use flakes
  nix.channel.enable = false;

  environment.shells = [ pkgs.fish ];
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

  networking.computerName = "Dante's MacBook Pro";
  networking.hostName = "${hostname}";
  networking.knownNetworkServices = [ "Wi-Fi" ];
  networking.dns = [
    "1.1.1.1" # Cloudflare
    "8.8.8.8" # Google
  ];

  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      cleanup = "zap";
    };
    casks = [
      "1password"
      "spotify"
      "arc"
      "raycast"
      "slack"
      "docker"
      "postgres-unofficial"
      "postico"
      "ghostty"
      "linear-linear"
      "visual-studio-code" # Required for run-electon-as-node
    ];
    taps = builtins.attrNames config.nix-homebrew.taps;
  };

  # Hack: https://github.com/ghostty-org/ghostty/discussions/2832
  environment.variables.XDG_DATA_DIRS = [ "$GHOSTTY_SHELL_INTEGRATION_XDG_DIR" ];
  environment.systemPath = [ "/Applications/Ghostty.app/Contents/MacOS/" ];
}
