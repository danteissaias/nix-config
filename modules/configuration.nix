{
  pkgs,
  username,
  inputs,
  system,
  ...
}:

{

  nix.enable = true;

  nix.optimise.automatic = true;

  nix.settings = {
    experimental-features = "nix-command flakes";
    use-xdg-base-directories = true;

    # Recommended when using `direnv` etc.
    keep-derivations = true;
    keep-outputs = true;

    substituters = [ "https://danteissaias.cachix.org" ];
    trusted-public-keys = [
      "danteissaias.cachix.org-1:SP7pA1fVIJ+s6CCED5FjQGp+AhiBxIFDm3b17nA9Aa8="
    ];
  };

  # Don't need channels since I use flakes
  nix.channel.enable = false;

  environment.shells = [ pkgs.fish ];
  programs.fish.enable = true;

  system = {
    configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;
  };

  users.users.${username} = {
    name = username;
    home = "/Users/${username}";
    isHidden = false;
    shell = pkgs.fish;
  };

  nixpkgs = {
    hostPlatform = system;
    config.allowUnfree = true;
    config.packageOverrides = pkgs: {
      berkeley-mono = pkgs.callPackage ../pkgs/berkeley-mono.nix { };
      global-npm = pkgs.callPackage ../pkgs/global-npm.nix { };
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
