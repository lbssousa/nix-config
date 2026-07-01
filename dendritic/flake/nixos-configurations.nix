{ config, inputs, ... }:
let
  inherit (inputs.nixpkgs) lib;
  inherit (config.dendritic) hosts;

  mkHost =
    hostname: hostSpec:
    lib.nixosSystem {
      specialArgs = {
        inherit inputs;
        inherit (config) flake;
      };
      modules = [
        {
          nixpkgs.hostPlatform.system = hostSpec.system;
          nixpkgs.overlays = [ config.dendritic.localOverlay ];
        }

        inputs.disko.nixosModules.disko
        inputs.preservation.nixosModules.default
        inputs.sops-nix.nixosModules.sops
        inputs.nix-flatpak.nixosModules.nix-flatpak
      ]
      ++ config.dendritic.nixos.sharedModules
      ++ config.dendritic.nixos.userModules
      ++ [
        ../../hosts/${hostname}/hardware-configuration.nix
        ../../hosts/${hostname}/configuration.nix
      ]
      ++ hostSpec.extraNixosModules;
    };
in
{
  flake.nixosConfigurations = lib.mapAttrs mkHost hosts;
}
