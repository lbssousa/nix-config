{
  description = "NixOS configuration with Btrfs, impermanence, KDE Plasma, and hybrid swap";

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

    # flake-parts for modular flake composition
    flake-parts = {
      url = "git+https://github.com/hercules-ci/flake-parts?rev=3107b77cd68437b9a76194f0f7f9c55f2329ca5b&shallow=1";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

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
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = import ./dendritic/imports.nix {
        root = ./dendritic;
        lib = inputs.nixpkgs.lib;
      };

      systems = [ "x86_64-linux" ];
    };
}
