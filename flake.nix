{
  description = "NixOS configuration with Btrfs, preservation, and hybrid swap";

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

    # Preservation for ephemeral root
    preservation.url = "github:nix-community/preservation";

    # NixOS hardware profiles
    nixos-hardware.url = "github:NixOS/nixos-hardware";

    # sops-nix for secret management (Wi-Fi passwords, etc.)
    sops-nix = {
      url = "github:mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Separate repository with the SOPS/age secrets
    nix-secrets = {
      url = "git+ssh://git@github.com/lbssousa/nix-secrets?shallow=1";
      flake = true;
    };

    # nix-flatpak for declarative Flatpaks with no nixpkgs equivalent
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=v0.7.0";

    # nixvim for declarative Neovim configuration
    nixvim.url = "github:nix-community/nixvim";

    # nix-wrapper-modules — packages programs with config baked into the store
    wrapper-modules.url = "github:BirdeeHub/nix-wrapper-modules";

  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = import ./dendritic/imports.nix {
        root = ./dendritic;
        inherit (inputs.nixpkgs) lib;
      };

      systems = [ "x86_64-linux" ];
    };
}
