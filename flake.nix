{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    catppuccin.url = "github:catppuccin/nix";

    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
  };

  outputs =
    inputs:
    let
      system = "aarch64-darwin";
      hostname = "speedy";
      username = "dante";
      specialArgs = {
        inherit username hostname inputs;
      };
    in
    {
      darwinConfigurations."${hostname}" = inputs.nix-darwin.lib.darwinSystem {
        inherit system specialArgs;
        modules = [
          ./configuration.nix
          inputs.home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = specialArgs;
            home-manager.users.${username} = {
              imports = [
                ./home-manager/home.nix
                inputs.catppuccin.homeModules.catppuccin
              ];
            };
          }
        ];
      };
    };
}
