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
      "hmFixHomeOwnership"
    ];
    text = lib.concatMapStrings (username: ''
      install -d -m 0755 -o "${username}" /nix/var/nix/profiles/per-user/${username}
    '') users;
  };

  # Corrige a propriedade de qualquer arquivo/diretório dentro de $HOME que
  # não pertence ao usuário correto. Isso é necessário quando UIDs mudam
  # entre gerações do sistema (p.ex., ao adicionar/remover usuários sem UIDs
  # fixos) — o btrfs @home persiste e mantém a propriedade antiga, causando
  # falha silenciosa no home-manager ao criar symlinks em gcroots.
  system.activationScripts.hmFixHomeOwnership = {
    deps = [ "users" ];
    text = lib.concatMapStrings (username: ''
      home_dir="/home/${username}"
      if [ -d "$home_dir" ]; then
        expected_uid="$(id -u "${username}" 2>/dev/null || true)"
        if [ -n "$expected_uid" ]; then
          # Corrige qualquer entrada (recursiva) que não pertença ao usuário.
          # -h: muda o dono do symlink em si (sem seguir o link) para evitar
          # erros de leitura em symlinks que apontam para o Nix store.
          find "$home_dir" -not -user "${username}" -print0 \
            | xargs -r0 chown -h "${username}:users"
        fi
      fi
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
