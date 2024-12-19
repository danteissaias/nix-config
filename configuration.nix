{
  self,
  inputs,
  pkgs,
  ...
}:

{
  imports = [ ./system.nix ];

  environment.systemPackages = [ pkgs.fish ];

  services.nix-daemon.enable = true;

  nix.optimise.automatic = true;

  nix.settings = {
    experimental-features = "nix-command flakes";
    use-xdg-base-directories = true;
  };

  fonts.packages = [ pkgs.jetbrains-mono ];

  programs.fish.enable = true;

  system = {
    stateVersion = 5;
    configurationRevision = self.rev or self.dirtyRev or null;
  };

  users.users.dante = {
    name = "dante";
    home = "/Users/dante";
    isHidden = false;
    shell = pkgs.fish;
  };

  nixpkgs = {
    hostPlatform = "aarch64-darwin";
    config.allowUnfree = true;
    overlays = [ inputs.fenix.overlays.default ];
  };

  security.pam.enableSudoTouchIdAuth = true;
}
