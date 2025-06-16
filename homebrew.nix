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
    casks = [
      "1password"
      "spotify"
      "arc"
      "thebrowsercompany-dia"
      "raycast"
      "slack"
      "docker"
      "postgres-unofficial"
      "postico"
      "ghostty"
      "linear-linear"
      "keycastr"
      "visual-studio-code" # Required for run-electon-as-node
    ];
    taps = builtins.attrNames config.nix-homebrew.taps;
  };

}
