{ config, inputs, ... }:
let
  inherit (inputs.nixpkgs) lib;
  inherit (config.dendritic) users hosts;

  mkPkgs =
    system:
    import inputs.nixpkgs {
      inherit system;
      config.allowUnfree = true;
      overlays = [ config.dendritic.localOverlay ];
    };

  mkHomeConfig =
    username: _hostname: hostSpec:
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = mkPkgs hostSpec.system;
      extraSpecialArgs = { inherit inputs; };
      modules = [
        inputs.sops-nix.homeManagerModules.sops
        ../../home/common.nix
        {
          home.username = lib.mkDefault username;
          home.homeDirectory = lib.mkDefault "/home/${username}";
        }
      ]
      ++ lib.optional (lib.pathExists (../../home/users + "/${username}/home.nix")) (
        ../../home/users + "/${username}/home.nix"
      );
    };
in
{
  flake.homeConfigurations = builtins.listToAttrs (
    lib.concatLists (
      lib.mapAttrsToList (
        hostname: hostSpec:
        map (username: {
          name = "${username}@${hostname}";
          value = mkHomeConfig username hostname hostSpec;
        }) users
      ) hosts
    )
  );
}
