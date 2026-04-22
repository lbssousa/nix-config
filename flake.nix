{
  description = "NixOS configuration with Btrfs, impermanence, GNOME, and hybrid swap";

  # Cache binário da comunidade Nix — disponibiliza artefatos pré-compilados do lanzaboote
  # e outros pacotes da nix-community, evitando compilações do zero (e downloads de crates.io).
  # Para ativar ao usar este flake manualmente, passe --accept-flake-config ao nix.
  nixConfig = {
    extra-substituters = [ "https://nix-community.cachix.org" ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCUSeBs="
    ];
  };

  inputs = {
    # NixOS unstable channel
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Home Manager
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Disko for declarative disk partitioning
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Impermanence for ephemeral root
    impermanence.url = "github:nix-community/impermanence";

    # NixOS hardware profiles
    nixos-hardware.url = "github:NixOS/nixos-hardware";

    # Lanzaboote for Secure Boot (used on barbudus for NVIDIA module signing)
    lanzaboote.url = "github:nix-community/lanzaboote/v0.4.1";

    # nix-homebrew for Linuxbrew/Homebrew support
    # NOTA: O suporte ao Homebrew é configurado diretamente em modules/homebrew.nix
    # sem dependência de um flake externo. Este input é mantido para uso futuro.
    # nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      disko,
      impermanence,
      lanzaboote,
      ...
    }@inputs:
    let
      # Optional private layer support.
      # Clone lbssousa/nixos-config-private into ./private (gitignored), then run:
      #   git add --force private/
      # This makes the private files visible to Nix without committing them.
      # The file must return a list of NixOS modules (attrsets or paths).
      # See docs/private-layer.md for the full workflow and expected structure.
      privateModules =
        if builtins.pathExists ./private/modules.nix then import ./private/modules.nix else [ ];

      # Helper to build a NixOS configuration for a given host
      mkHost =
        hostname: system: extraModules:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [
            # Disko module
            disko.nixosModules.disko

            # Impermanence module
            impermanence.nixosModules.impermanence

            # Host-specific hardware configuration
            ./hosts/${hostname}/hardware-configuration.nix

            # Host-specific system configuration
            ./hosts/${hostname}/configuration.nix

            # Home Manager as NixOS module
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "hm-backup";
                # User-specific home-manager configs are loaded from ./users/
                # See users/skeleton.nix for the template
                # Real user configs are gitignored (see .gitignore)
                # Private-layer users are loaded from ./private/ (see docs/private-layer.md)
              };
            }
          ]
          ++ extraModules
          ++ privateModules;
        };
    in
    {
      # NixOS configurations
      nixosConfigurations = {
        # Dell Inspiron 14 5490 (Intel i5-10210U, 16GB RAM, Intel + Nvidia MX230)
        # NOTA: Não há módulo nixos-hardware específico para este modelo.
        # Se disponível no futuro, adicione em extraModules.
        # O módulo lanzaboote é incluído apenas para este host (usa Secure Boot)
        barbudus = mkHost "barbudus" "x86_64-linux" [ lanzaboote.nixosModules.lanzaboote ];

        # Morefine M6 Mini-PC (Intel N200, 16GB RAM, Intel UHD Graphics)
        bigodon = mkHost "bigodon" "x86_64-linux" [ ];
      };

      # Expose disko configurations for standalone partitioning
      diskoConfigurations = {
        barbudus = import ./hosts/barbudus/disko.nix { inherit (nixpkgs) lib; };
        bigodon = import ./hosts/bigodon/disko.nix { inherit (nixpkgs) lib; };
      };
    };
}
