# Shared Home Manager building blocks, consumed both by the NixOS module
# wiring (dendritic/flake/home-nixos-module.nix) and by the standalone
# flake outputs (dendritic/flake/home-configurations.nix). Keeping a single
# definition guarantees the two deployment paths never drift apart.
{ inputs }:
let
  inherit (inputs.nixpkgs) lib;
in
{
  sharedModules = [
    inputs.nixvim.homeModules.nixvim
    inputs.sops-nix.homeManagerModules.sops
  ];

  # Per-user HM module: common.nix + user-specific home.nix (if it exists)
  userModule = username: {
    imports = [
      ./common.nix
    ]
    ++ lib.optional (lib.pathExists (./users + "/${username}/home.nix")) (
      ./users + "/${username}/home.nix"
    );
  };
}
