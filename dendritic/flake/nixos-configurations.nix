{ config, inputs, ... }:
let
  inherit (inputs.nixpkgs) lib;

  hosts = config.dendritic.hosts;

  mkHost =
    hostname: hostSpec: desktop:
    lib.nixosSystem {
      system = hostSpec.system;
      modules = [
        { nixpkgs.overlays = [ config.dendritic.localOverlay ]; }
        { my.desktop.environment = desktop; }

        # Modulos cross-cutting de feature no escopo de sistema.
        {
          environment.systemPackages = [
            inputs.home-manager.packages.${hostSpec.system}.default
          ];
        }

        inputs.disko.nixosModules.disko
        inputs.impermanence.nixosModules.impermanence
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

  mkCanonical =
    hostname: hostSpec:
    {
      name = hostname;
      value = mkHost hostname hostSpec hostSpec.defaultDesktop;
    };

  mkDesktopVariants =
    hostname: hostSpec:
    lib.listToAttrs (
      map (desktop: {
        name = "${hostname}-${desktop}";
        value = mkHost hostname hostSpec desktop;
      }) config.dendritic.desktops
    );
in
{
  flake.nixosConfigurations =
    lib.mapAttrs' mkCanonical hosts
    // lib.foldl' lib.recursiveUpdate { } (lib.mapAttrsToList mkDesktopVariants hosts);
}
