{
  pkgs,
  username,
  inputs,
  ...
}:

{
  imports = [
    ./system.nix
    ./homebrew.nix
  ];

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
    stateVersion = 6;
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
    config.packageOverrides = pkgs: {
      berkeley-mono = pkgs.callPackage ./pkgs/berkeley-mono.nix { };
    };
  };

  fonts = {
    packages = with pkgs; [
      berkeley-mono
    ];
  };

  # Hack: https://github.com/ghostty-org/ghostty/discussions/2832
  environment.variables.XDG_DATA_DIRS = [ "$GHOSTTY_SHELL_INTEGRATION_XDG_DIR" ];
  environment.systemPath = [ "/Applications/Ghostty.app/Contents/MacOS/" ];
}
