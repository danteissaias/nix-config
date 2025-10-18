{
  networking.computerName = "Dante's MacBook Pro (M4)";
  networking.hostName = "m4";
  system.stateVersion = 6;

  services.cachix-agent = {
    enable = true;
    name = "m4";
  };
}
