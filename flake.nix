{
  description = "Noctalia Family NixOS dotfiles (sashi-main / sashi-letsnote)";

  nixConfig = {
    # Binary caches for the two non-nixpkgs package sources used here:
    # chaotic-nyx (CachyOS kernel) and aagl (anime game launchers).
    extra-substituters = [
      "https://nyx-cache.chaotic.cx/"
      "https://ezkea.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nyx-cache.chaotic.cx:dJxTrgMC3V3cFfyIiBQDQorG6k1LsqurH/srpMSq7qk="
      "ezkea.cachix.org-1:ioBmUbJTZIKsHmWWXPe1FSFbeVe+afhfgqgTSNd34eI="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Intentionally not following our nixpkgs: chaotic-nyx pins its own
    # nixpkgs revision so its binary cache substitutions actually hit.
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    aagl = {
      url = "github:ezKEa/aagl-gtk-on-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Pinned stable release, not master.  Keeping nixpkgs following our own
    # input avoids pulling a second copy of nixpkgs into the closure.
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.2.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      aagl,
      chaotic,
      lanzaboote,
      ...
    }@inputs:
    let
      system = "x86_64-linux";

      mkHost =
        host:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [
            ./hosts/${host}/default.nix
            lanzaboote.nixosModules.lanzaboote
            home-manager.nixosModules.home-manager
            aagl.nixosModules.default
            chaotic.nixosModules.default
            {
              nix.settings = aagl.nixConfig;

              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = { inherit inputs; };
            }
          ];
        };
    in
    {
      nixosConfigurations = {
        sashi-main = mkHost "sashi-main";
        sashi-letsnote = mkHost "sashi-letsnote";
      };

      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt;
    };
}
