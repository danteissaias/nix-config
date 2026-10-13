{
  username,
  inputs,
  config,
  ...
}:

{
  nix-homebrew = {
    enable = true;

    enableRosetta = false;

    user = "${username}";

    taps = {
      "homebrew/homebrew-core" = inputs.homebrew-core;
      "homebrew/homebrew-cask" = inputs.homebrew-cask;
    };

    mutableTaps = false;
  };

  homebrew = {
    enable = true;
    onActivation = {
      # Taps are pinned by flake inputs; update them with `nix flake update`.
      autoUpdate = false;
      cleanup = "zap";
    };
    casks = [
      "1password"
      "spotify"
      "thebrowsercompany-dia"
      "slack"
      "postico"
      "cleanshot"
      "orbstack"
      "superhuman"
      "raycast"
      "notion-calendar"
      "tailscale-app"
    ];
    taps = builtins.attrNames config.nix-homebrew.taps;
  };

}
