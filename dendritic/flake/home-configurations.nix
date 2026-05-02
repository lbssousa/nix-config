{ config, inputs, ... }:
let
  inherit (inputs.nixpkgs) lib;

  hosts = config.dendritic.hosts;
  users = config.dendritic.users;

  mkHome =
    username: system: desktop:
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = inputs.nixpkgs.legacyPackages.${system}.extend config.dendritic.localOverlay;
      extraSpecialArgs = {
        inherit desktop;
      };
      modules = [
        ../../home/common.nix
        {
          home.username = username;
          home.homeDirectory = "/home/${username}";
        }
      ] ++ lib.optionals (username == abutre) [ ../../home/users/abutre/home.nix ];
    };

  mkUserHostEntries =
    username:
    lib.mapAttrs' (
      hostname: hostSpec:
      {
        name = "${username}@${hostname}";
        value = mkHome username hostSpec.system "gnome";
      }
    ) hosts;

  mkUserHostDesktopEntries =
    username:
    lib.foldl' lib.recursiveUpdate { } (
      lib.mapAttrsToList (
        hostname: hostSpec:
        lib.listToAttrs (
          map (desktop: {
            name = "${username}@${hostname}-${desktop}";
            value = mkHome username hostSpec.system desktop;
          }) config.dendritic.desktops
        )
      ) hosts
    );

  entriesPerUser =
    username:
    mkUserHostEntries username
    // mkUserHostDesktopEntries username;
in
{
  flake.homeConfigurations = lib.foldl' lib.recursiveUpdate { } (map entriesPerUser users);
}
