{
  description = "Han-Tyumi's Darwin System";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    fh.url = "https://flakehub.com/f/DeterminateSystems/fh/*.tar.gz";
    flake-checker.url = "https://flakehub.com/f/DeterminateSystems/flake-checker/*.tar.gz";

    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nix-darwin, home-manager, ... }: {
    # Build darwin flake using:
    # $ darwin-rebuild build --flake .#Matts-MacBook-Pro
    darwinConfigurations."Matts-MacBook-Pro" = nix-darwin.lib.darwinSystem {
      modules = [
        ./configuration.nix
        home-manager.darwinModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;

            users.han-tyumi = import ./home.nix;
          };
        }
      ];
      specialArgs = { inherit inputs; };
    };

    # Expose the package set, including overlays, for convenience.
    darwinPackages = self.darwinConfigurations."Matts-MacBook-Pro".pkgs;
  };
}
