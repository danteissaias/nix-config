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
    warn-dirty = false;

    substituters = [
      "https://nix-community.cachix.org"
      "https://cache.numtide.com" # llm-agents.nix
    ];
    trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];

    # Recommended when using `direnv` etc.
    keep-derivations = true;
    keep-outputs = true;
  };

  # Don't need channels since I use flakes
  nix.channel.enable = false;

  # Work around a nix-darwin/nixpkgs mismatch where nix-darwin's HTML manual
  # still passes the removed `--toc-depth` flag to nixos-render-docs.
  # Keep man/info docs enabled; only skip the generated HTML manual/darwin-help app.
  documentation.doc.enable = false;
  # The uninstaller package evaluates a separate default nix-darwin system whose
  # docs still hit the same renderer incompatibility.
  system.tools.darwin-uninstaller.enable = false;

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
    overlays = [
      (final: prev: {
        berkeley-mono = final.callPackage ../pkgs/berkeley-mono.nix { };
        jj-starship = final.callPackage ../pkgs/jj-starship.nix { };
        jj-ryu = final.callPackage ../pkgs/jj-ryu.nix { };
        terraform = final.callPackage ../pkgs/terraform.nix { };
      })
    ];
  };

  fonts = {
    packages = with pkgs; [
      berkeley-mono
    ];
  };

  # Rex ships its CLI inside a nested helper app bundle whose path contains
  # spaces, which breaks environment.systemPath. Wrap it in a space-free
  # `rex` command on PATH instead.
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "rex" ''
      exec "/Applications/Rex Beta.app/Contents/Helpers/Rex Server.rex/Contents/MacOS/rex" "$@"
    '')
  ];
}
