# Módulo de usuários: Esqueleto para definição de usuários
# Os arquivos reais de usuário ficam em users/ e são ignorados pelo git
# Consulte users/skeleton.nix para criar seu arquivo de usuário
{
  config,
  lib,
  pkgs,
  ...
}:

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
  #
  # IMPLEMENTAÇÃO COMO SERVIÇO SYSTEMD (não activation script):
  # O bind mount de /etc/shadow via impermanence é feito por um serviço systemd que roda
  # antes de local-fs.target. Se usarmos um activation script, o chage escreveria no
  # tmpfs de /etc/shadow, que seria sobrescrito pelo bind mount logo em seguida — perdendo
  # o efeito do chage. Como serviço (after = local-fs.target), o bind mount já está ativo
  # quando o chage roda, garantindo que a marcação de expiração persista no /persist.
  #
  # Para redefinir: apague /persist/.password-change-required-<usuario>.
  # Em sistemas existentes onde o flag já foi criado por versões anteriores (activation script),
  # apague o flag e reinicie para que o serviço aplique o chage corretamente.
  systemd.services.forceInitialPasswordChange = lib.mkIf (usersWithInitialPassword != { }) {
    description = "Forçar troca de senha no primeiro login (usuários com senha inicial)";
    wantedBy = [ "multi-user.target" ];
    # Rodar após local-fs.target garante que o bind mount de /etc/shadow via impermanence
    # já está ativo, então chage escreve no arquivo persistido em /persist/etc/shadow.
    after = [ "local-fs.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = lib.concatMapStrings (
      username:
      let
        flagFile = lib.escapeShellArg "/persist/.password-change-required-${username}";
        escapedUser = lib.escapeShellArg username;
      in
      ''
        if [ ! -f ${flagFile} ]; then
          if ${pkgs.shadow}/bin/chage -d 0 ${escapedUser}; then
            touch ${flagFile}
          else
            echo "forceInitialPasswordChange: chage falhou para ${escapedUser}" >&2
          fi
        fi
      ''
    ) (lib.attrNames usersWithInitialPassword);
  };
}
