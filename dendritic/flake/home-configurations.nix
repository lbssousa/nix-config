# Standalone Home Manager outputs — `home-manager switch --flake .#<user>@<host>`
# deploys only the user environment, independent of `nixos-rebuild`. Reuses
# the exact same modules as the NixOS-coupled path (home-nixos-module.nix),
# via home/mkUserHome.nix, so both stay in sync by construction.
#
# NOTE: unlike the NixOS-coupled path, nothing re-applies this automatically
# on boot (/home is tmpfs, see modules/system/core/preservation.nix).
# `home-manager switch` must be run again after every reboot to restore
# packages/dotfiles that aren't otherwise covered by preservation.
{ config, inputs, ... }:
let
  inherit (inputs.nixpkgs) lib;
  inherit (config.dendritic) hosts users;
  inherit (import ../../home/mkUserHome.nix { inherit inputs; }) userModule sharedModules;

  mkPkgsFor =
    system:
    import inputs.nixpkgs {
      inherit system;
      overlays = [ config.dendritic.localOverlay ];
      config.allowUnfree = true; # mirrors modules/system/core/common.nix
    };

  mkHomeConfiguration =
    hostname: hostSpec: username:
    lib.nameValuePair "${username}@${hostname}" (
      inputs.home-manager.lib.homeManagerConfiguration {
        pkgs = mkPkgsFor hostSpec.system;
        extraSpecialArgs = {
          inherit inputs;
          # flake: flake outputs (e.g. packages.helix used in modules/home/apps/editors/helix/)
          inherit (config) flake;
        };
        modules = sharedModules ++ [
          {
            home.username = username;
            home.homeDirectory = "/home/${username}";
          }
          (userModule username)
        ];
      }
    );
in
{
  flake.homeConfigurations = lib.listToAttrs (
    lib.flatten (
      lib.mapAttrsToList (hostname: hostSpec: map (mkHomeConfiguration hostname hostSpec) users) hosts
    )
  );
}
