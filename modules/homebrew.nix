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
      autoUpdate = true;
      cleanup = "zap";
    };
    brews = [
      "n"
    ];
    casks = [
      "1password"
      "spotify"
      "thebrowsercompany-dia"
      "raycast"
      "slack"
      "docker"
      "postgres-unofficial"
      "postico"
      "ghostty"
      "visual-studio-code" # Required for run-electon-as-node
      "cleanshot"
    ];
    taps = builtins.attrNames config.nix-homebrew.taps;
  };

}
