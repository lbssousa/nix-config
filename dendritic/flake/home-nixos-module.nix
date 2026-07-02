{ config, inputs, ... }:
let
  inherit (inputs.nixpkgs) lib;
  users = config.dendritic.users;

  # Módulo HM por usuário: common.nix + home.nix específico (se existir)
  mkUserHome =
    username:
    {
      imports =
        [ ../../home/common.nix ]
        ++ lib.optional
          (lib.pathExists (../../home/users + "/${username}/home.nix"))
          (../../home/users + "/${username}/home.nix");
    };
in
{
  dendritic.nixos.sharedModules = [
    inputs.home-manager.nixosModules.home-manager
    {
      home-manager = {
        # Usa o nixpkgs do sistema (overlay local e allowUnfree já aplicados).
        useGlobalPkgs = true;
        # Instala pacotes em /etc/profiles/per-user/<user> em vez de ~/.nix-profile.
        useUserPackages = true;
        # Preserva arquivos conflitantes com extensão .bkp
        backupFileExtension = "bkp";
        extraSpecialArgs = {
          inherit inputs;
          # flake: saídas do flake (ex.: packages.helix usado em modules/home/apps/editors/helix/)
          flake = config.flake;
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
