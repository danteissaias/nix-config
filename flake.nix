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

    cachix-deploy.url = "github:cachix/cachix-deploy-flake";
  };

  outputs =
    inputs:
    let
      system = "aarch64-darwin";
      username = "dante";
      pkgs = import inputs.nixpkgs { inherit system; };
      cachix-deploy-lib = inputs.cachix-deploy.lib pkgs;

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
      };

      packages.${system}.default = cachix-deploy-lib.spec {
        agents.m4 = inputs.self.darwinConfigurations.m4.system;
      };
    };
}
