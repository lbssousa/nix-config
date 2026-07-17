{ config, inputs, ... }:
let
  inherit (inputs.nixpkgs) lib;
  inherit (config.dendritic) users;
  inherit (import ../../home/mkUserHome.nix { inherit inputs; }) userModule sharedModules;
in
{
  dendritic.nixos.sharedModules = [
    inputs.home-manager.nixosModules.home-manager
    {
      home-manager = {
        # Uses the system's nixpkgs (local overlay and allowUnfree already applied).
        useGlobalPkgs = true;
        # Installs packages to /etc/profiles/per-user/<user> instead of ~/.nix-profile.
        useUserPackages = true;
        # Preserves conflicting files with a .bkp extension
        backupFileExtension = "bkp";
        extraSpecialArgs = {
          inherit inputs;
          # flake: flake outputs (e.g. packages.helix used in modules/home/apps/editors/helix/)
          inherit (config) flake;
        };
        inherit sharedModules;
        users = lib.genAttrs users userModule;
      };
    }
  ];
}
