{ inputs, ... }:
let
  # Overlay com pacotes customizados não disponíveis no nixpkgs oficial
  localOverlay = final: _prev: {
    epson-printer-utility = final.callPackage ../pkgs/epson-printer-utility/package.nix { };
  };

  # Helper to build a NixOS configuration for a given host
  mkHost =
    hostname: system: extraModules: desktop:
    inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs; };
      modules = [
        { nixpkgs.overlays = [ localOverlay ]; }
        # Seleção de ambiente desktop por variante do flake
        { my.desktop.environment = desktop; }
        # Disko module
        inputs.disko.nixosModules.disko
        # Impermanence module
        inputs.impermanence.nixosModules.impermanence
        # Host-specific hardware configuration
        ../hosts/${hostname}/hardware-configuration.nix
        # Host-specific system configuration
        ../hosts/${hostname}/configuration.nix
        # sops-nix for secret management
        inputs.sops-nix.nixosModules.sops
        # nix-flatpak for declarative Flatpak management
        inputs.nix-flatpak.nixosModules.nix-flatpak
      ]
      ++ extraModules;
    };
in
{
  flake.nixosConfigurations = {
    # Dell Inspiron 14 5490 (Intel i5-10210U, 16GB RAM, Intel + Nvidia MX230)
    # O módulo lanzaboote é incluído apenas para este host (usa Secure Boot)
    barbudus = mkHost "barbudus" "x86_64-linux" [ inputs.lanzaboote.nixosModules.lanzaboote ] "plasma";
    barbudus-gnome = mkHost "barbudus" "x86_64-linux" [
      inputs.lanzaboote.nixosModules.lanzaboote
    ] "gnome";
    barbudus-plasma = mkHost "barbudus" "x86_64-linux" [
      inputs.lanzaboote.nixosModules.lanzaboote
    ] "plasma";

    # Morefine M6 Mini-PC (Intel N200, 16GB RAM, Intel UHD Graphics)
    bigodon = mkHost "bigodon" "x86_64-linux" [ ] "plasma";
    bigodon-gnome = mkHost "bigodon" "x86_64-linux" [ ] "gnome";
    bigodon-plasma = mkHost "bigodon" "x86_64-linux" [ ] "plasma";
  };
}
