{ config, inputs, ... }:
let
  inherit (inputs.nixpkgs) lib;
  users = config.dendritic.users;

  # Per-user HM module: common.nix + user-specific home.nix (if it exists)
  mkUserHome = username: {
    imports = [
      ../../home/common.nix
    ]
    ++ lib.optional (lib.pathExists (../../home/users + "/${username}/home.nix")) (
      ../../home/users + "/${username}/home.nix"
    );
  };
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
        sharedModules = [
          inputs.nixvim.homeModules.nixvim
          inputs.sops-nix.homeManagerModules.sops
        ];
        users = lib.genAttrs users mkUserHome;
      };
    }
  ];
}
