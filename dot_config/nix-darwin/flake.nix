{
  description = "Darwin system configuration";

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

      # Per-machine identity and enabled layers, rendered by chezmoi from its data.
      machine = import ./machine.nix;

      # A layer named N can ship modules in-repo (modules/N) and/or from a private
      # overlay clone (overlays/N, a chezmoi-managed external). Missing files are
      # skipped, so a machine whose overlay clone hasn't landed yet still builds.
      layerModules =
        fileName: layers:
        builtins.filter builtins.pathExists (
          lib.concatMap (name: [
            (./modules + "/${name}/${fileName}")
            (./overlays + "/${name}/${fileName}")
          ]) layers
        );

      mkSystem =
        machine:
        nix-darwin.lib.darwinSystem {
          specialArgs = { inherit inputs machine; };
          modules = [
            ./modules/shared/darwin.nix
            home-manager.darwinModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "backup";

                users.${machine.username}.imports = [
                  ./modules/shared/home.nix
                ]
                ++ layerModules "home.nix" machine.layers;

                extraSpecialArgs = { inherit inputs machine; };
              };
            }
          ]
          ++ layerModules "darwin.nix" machine.layers;
        };

      # Eval-only fixtures: every in-repo layer alone, plus everything at once.
      onlyDirs = lib.filterAttrs (_: type: type == "directory");
      inRepoLayers = lib.filter (name: name != "shared") (
        builtins.attrNames (onlyDirs (builtins.readDir ./modules))
      );
      overlayLayers = lib.optionals (builtins.pathExists ./overlays) (
        builtins.attrNames (onlyDirs (builtins.readDir ./overlays))
      );
      testFor =
        layers:
        mkSystem {
          inherit (machine) username hostname;
          inherit layers;
        };
    in
    {
      # The machine's own attr is merged last so it always wins a name collision
      # with a test fixture.
      darwinConfigurations = {
        test-minimal = testFor [ ];
        test-all = testFor (lib.unique (inRepoLayers ++ overlayLayers));
      }
      // lib.listToAttrs (map (name: lib.nameValuePair "test-${name}" (testFor [ name ])) inRepoLayers)
      // {
        ${machine.hostname} = mkSystem machine;
      };

      # Expose the package set, including overlays, for convenience.
      darwinPackages = self.darwinConfigurations.${machine.hostname}.pkgs;
    };
}
