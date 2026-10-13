{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    catppuccin = {
      url = "github:catppuccin/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Do not follow our nixpkgs, so builds hit nix-community.cachix.org.
    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # No `follows`: use their nixpkgs so builds hit cache.numtide.com.
    llm-agents.url = "github:numtide/llm-agents.nix";

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

      mkDarwinSystem =
        hostname:
        inputs.nix-darwin.lib.darwinSystem {
          inherit system;
          specialArgs = { inherit inputs username system; };
          modules = [
            inputs.nix-homebrew.darwinModules.nix-homebrew
            inputs.home-manager.darwinModules.home-manager
            ./modules/configuration.nix
            ./modules/system.nix
            ./modules/homebrew.nix
            ./hosts/${hostname}.nix
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = { inherit inputs username; };
                users.${username} = import ./home-manager/home.nix;
              };
            }
          ];
        };
    in
    {
      darwinConfigurations = {
        speedy = mkDarwinSystem "speedy";
        m4 = mkDarwinSystem "m4";
        m5 = mkDarwinSystem "m5";
      };
    };
}
