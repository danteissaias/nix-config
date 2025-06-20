{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    catppuccin.url = "github:catppuccin/nix";

    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
  };

  outputs =
    inputs:
    let
      system = "aarch64-darwin";
      username = "dante";

      overlays = [
        (final: prev: {
          claude-code =
            (import inputs.nixpkgs-master {
              inherit system;
              config = final.config; # Use the same config as current nixpkgs
            }).claude-code;
        })
      ];

      specialArgs = {
        inherit username inputs system;
      };

      darwinModules = [
        inputs.nix-homebrew.darwinModules.nix-homebrew
        inputs.home-manager.darwinModules.home-manager
        ./modules/configuration.nix
        ./modules/system.nix
        ./modules/homebrew.nix
        {
          nixpkgs.overlays = overlays;
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            extraSpecialArgs = specialArgs;
            users.${username} = {
              imports = [
                ./modules/home.nix
                inputs.catppuccin.homeModules.catppuccin
              ];
            };
          };
        }
      ];
    in
    {
      darwinConfigurations."speedy" = inputs.nix-darwin.lib.darwinSystem {
        inherit system specialArgs;
        modules = [
          ./hosts/speedy.nix
        ] ++ darwinModules;
      };
    };
}
