# Módulo de usuários: Esqueleto para definição de usuários
# Os arquivos reais de usuário ficam em users/ e são ignorados pelo git
# Consulte users/skeleton.nix para criar seu arquivo de usuário
{ config, lib, pkgs, ... }:

let
  # Usuários normais com senha inicial declarada (initialPassword ou initialHashedPassword).
  # Para esses usuários o sistema força a troca de senha no primeiro login,
  # usando um arquivo de flag em /persist para que a exigência ocorra apenas uma vez.
  usersWithInitialPassword = lib.filterAttrs (
    _name: user:
    user.isNormalUser && (user.initialPassword != null || user.initialHashedPassword != null)
  ) config.users.users;
in
{
  # Habilitar Zsh globalmente (necessário para usar como shell de usuário)
  programs.zsh.enable = true;
  programs.fish.enable = true;

  # Configuração padrão de sudo
  security.sudo = {
    enable = true;
    wheelNeedsPassword = true;
  };

  # Os usuários reais são definidos em arquivos separados (não commitados)
  # Exemplo: users/joao.nix
  # Para criar um usuário, copie users/skeleton.nix para users/<seu-usuario>.nix
  # e descomente/ajuste as configurações

  # Configuração de grupos padrão disponíveis
  users.groups = {
    plugdev = { }; # Acesso a dispositivos USB
    dialout = { }; # Portas seriais
    video = { }; # Acesso à GPU
    audio = { }; # Acesso ao áudio
    docker = { }; # Compatibilidade com Docker (Podman)
  };

  # Força a troca de senha no primeiro login para usuários com initialPassword/initialHashedPassword.
  # Usa um arquivo de flag em /persist para que a troca seja exigida apenas uma vez.
  # Para redefinir: apague /persist/.password-change-required-<usuario>.
  system.activationScripts.forceInitialPasswordChange = {
    deps = [ "users" ];
    text = lib.concatMapStrings (
      username:
      let
        flagFile = lib.escapeShellArg "/persist/.password-change-required-${username}";
        escapedUser = lib.escapeShellArg username;
      in
      ''
        if [ ! -f ${flagFile} ]; then
          ${pkgs.shadow}/bin/chage -d 0 ${escapedUser} && touch ${flagFile} \
            || echo "forceInitialPasswordChange: chage failed for ${escapedUser}" >&2
        fi
      ''
    ) (lib.attrNames usersWithInitialPassword);
  };
}
