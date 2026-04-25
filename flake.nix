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
    lanzaboote.url = "github:nix-community/lanzaboote/v1.0.0";

    # sops-nix for secret management (Wi-Fi passwords, etc.)
    sops-nix = {
      url = "github:mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nix-flatpak for declarative Flatpak management
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=v0.7.0";

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
      sops-nix,
      nix-flatpak,
      ...
    }@inputs:
    let
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

            # sops-nix for secret management
            sops-nix.nixosModules.sops

            # nix-flatpak for declarative Flatpak management
            nix-flatpak.nixosModules.nix-flatpak
          ]
          ++ extraModules;
        };

      # Helper to build a standalone Home Manager configuration for a given user/host
      mkHome =
        username: system: extraModules:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          extraSpecialArgs = { inherit inputs; };
          modules = [
            # Global Home Manager configuration (common to all users)
            ./home/common.nix
            # User identity
            {
              home.username = username;
              home.homeDirectory = "/home/${username}";
            }
          ] ++ extraModules;
        };

      # Hosts and their system architectures
      allHosts = {
        barbudus = "x86_64-linux";
        bigodon = "x86_64-linux";
      };

      # Generate homeConfigurations entries for a user across all hosts
      mkHomeAllHosts =
        username: extraModules:
        nixpkgs.lib.mapAttrs' (hostname: system: {
          name = "${username}@${hostname}";
          value = mkHome username system extraModules;
        }) allHosts;
    in
    {
      # NixOS configurations (system-level — run with: nixos-rebuild switch --flake .#<host>)
      nixosConfigurations = {
        # Dell Inspiron 14 5490 (Intel i5-10210U, 16GB RAM, Intel + Nvidia MX230)
        # NOTA: Não há módulo nixos-hardware específico para este modelo.
        # Se disponível no futuro, adicione em extraModules.
        # O módulo lanzaboote é incluído apenas para este host (usa Secure Boot)
        barbudus = mkHost "barbudus" "x86_64-linux" [ lanzaboote.nixosModules.lanzaboote ];

        # Morefine M6 Mini-PC (Intel N200, 16GB RAM, Intel UHD Graphics)
        bigodon = mkHost "bigodon" "x86_64-linux" [ ];
      };

      # Home Manager configurations (user-level — run with: home-manager switch --flake .#<user>@<host>)
      # abutre: configuração personalizada (powerlevel10k, git SSH signing, Bitwarden)
      homeConfigurations =
        mkHomeAllHosts abutre [ ./home/users/abutre/home.nix ]
        // mkHomeAllHosts surubi [ ]
        // mkHomeAllHosts coruja [ ]
        // mkHomeAllHosts camelo [ ]
        // mkHomeAllHosts cavalo [ ]
        // mkHomeAllHosts macaco [ ];

      # Expose disko configurations for standalone partitioning
      diskoConfigurations = {
        barbudus = import ./hosts/barbudus/disko.nix { inherit (nixpkgs) lib; };
        bigodon = import ./hosts/bigodon/disko.nix { inherit (nixpkgs) lib; };
      };
    };
}
