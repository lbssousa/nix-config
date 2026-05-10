# Módulo NixOS: configura o home-manager como módulo do sistema para todos os
# usuários do inventário.
#
# Uso (em dendritic/features/nixos-modules.nix):
#   import ../../modules/system/users/home-manager.nix {
#     inherit inputs;
#     users = config.dendritic.users;
#   }
{ inputs, users }:
{ lib, ... }:
{
  # O script de ativação do HM (setupVars) exige que o diretório de perfil
  # do Nix já exista para o usuário antes que home-manager-<user>.service
  # inicie. Para usuários que nunca rodaram um comando nix (nunca fizeram
  # login), o nix-daemon não cria esse diretório automaticamente, causando
  # falha silenciosa. Garantimos a criação aqui como root, antes de "users".
  system.activationScripts.hmCreateNixProfileDirs = {
    deps = [
      "users"
    ];
    text = lib.concatMapStrings (username: ''
      install -d -m 0755 -o "${username}" /nix/var/nix/profiles/per-user/${username}
    '') users;
  };

  home-manager = {
    # Reutiliza o pkgs do sistema (inclui overlay local e allowUnfree).
    useGlobalPkgs = true;
    # Instala pacotes do usuário via users.users.<name>.packages (perfil NixOS).
    useUserPackages = true;
    # Preserva arquivos pré-existentes com extensão .bk em vez de falhar.
    backupFileExtension = "bk";

    extraSpecialArgs = { inherit inputs; };

    sharedModules = [ inputs.sops-nix.homeManagerModules.sops ];

    users = lib.genAttrs users (
      username:
      let
        userHomePath = ../../../home/users + "/${username}/home.nix";
      in
      {
        imports = [
          ../../../home/common.nix
        ]
        ++ lib.optional (lib.pathExists userHomePath) userHomePath;

        home.username = lib.mkDefault username;
        home.homeDirectory = lib.mkDefault "/home/${username}";
      }
    );
  };
}
