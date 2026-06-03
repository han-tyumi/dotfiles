{
  description = "Han-Tyumi's Darwin System";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-25.11-darwin";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nix-darwin,
      home-manager,
      ...
    }:
    let
      inherit (nixpkgs) lib;

      # Per-machine profile selection, rendered by chezmoi from its data.
      profiles = import ./profiles.nix;

      # Guarded so a machine whose work overlay isn't cloned yet still builds.
      workDarwin = ./modules/work/darwin.nix;
      workHome = ./modules/work/home.nix;

      mkSystem =
        profiles:
        nix-darwin.lib.darwinSystem {
          specialArgs = { inherit inputs profiles; };
          modules = [
            ./modules/shared/darwin.nix
            home-manager.darwinModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "backup";

                users.${profiles.username}.imports = [
                  ./modules/shared/home.nix
                ]
                ++ lib.optional profiles.personal ./modules/personal/home.nix
                ++ lib.optional (profiles.work && builtins.pathExists workHome) workHome;

                extraSpecialArgs = { inherit inputs profiles; };
              };
            }
          ]
          ++ lib.optional profiles.personal ./modules/personal/darwin.nix
          ++ lib.optional (profiles.work && builtins.pathExists workDarwin) workDarwin;
        };

      # Eval-only fixtures covering every profile combination.
      testProfiles = personal: work: {
        hostname = "test";
        username = profiles.username;
        inherit personal work;
      };
    in
    {
      darwinConfigurations = {
        ${profiles.hostname} = mkSystem profiles;

        test-minimal = mkSystem (testProfiles false false);
        test-personal = mkSystem (testProfiles true false);
        test-work = mkSystem (testProfiles false true);
        test-full = mkSystem (testProfiles true true);
      };

      # Expose the package set, including overlays, for convenience.
      darwinPackages = self.darwinConfigurations.${profiles.hostname}.pkgs;
    };
}
