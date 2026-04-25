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

  # Os usuários reais são definidos em arquivos separados em users/
  # Exemplo: users/laercio.nix
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

  # ─────────────────────────────────────────────────────────────────────────
  # Persistência do /etc/shadow (senhas de usuário)
  # ─────────────────────────────────────────────────────────────────────────
  #
  # PROBLEMA RAIZ: tanto o script de ativação 'users' do NixOS quanto
  # ferramentas como 'passwd' e 'chage' atualizam /etc/shadow via rename()
  # atômico. Qualquer bind mount em /etc/shadow é desfeito no instante do
  # rename, tornando o arquivo bind-mounted um inode órfão. Com tmpfs na
  # raiz (/), o /etc/shadow recém-criado fica apenas na RAM e é perdido no
  # próximo boot.
  #
  # SOLUÇÃO EM DOIS PASSOS:
  #
  # 1. Activation script 'restoreShadow' (deps = ["etc"]) — roda ANTES de
  #    'users' (via system.activationScripts.users.deps abaixo):
  #    Copia /persist/etc/shadow → /etc/shadow se existir, sem bind mount.
  #    Como 'users' tem users.mutableUsers = true (padrão NixOS), ao ler o
  #    /etc/shadow restaurado ele PRESERVA as senhas dos usuários existentes
  #    na saída do novo shadow, em vez de aplicar initialPassword.
  #
  # 2. Serviço systemd 'persistShadow' (path unit PathChanged=/etc/shadow):
  #    Monitora /etc/shadow com inotify (PathChanged detecta IN_MOVED_TO,
  #    ou seja, rename). Toda vez que /etc/shadow muda — seja por 'passwd',
  #    'chage', ou pelo script de ativação 'users' — copia imediatamente
  #    /etc/shadow → /persist/etc/shadow, garantindo a persistência.
  system.activationScripts.restoreShadow = {
    deps = [ "etc" ];
    text = ''
      mkdir -p /persist/etc
      if [ -f /persist/etc/shadow ]; then
        # Restaura o shadow persistido ANTES do script 'users' rodar.
        # Com users.mutableUsers = true (padrão NixOS), o script 'users'
        # lerá este arquivo e preservará as senhas dos usuários existentes.
        install -m 640 /persist/etc/shadow /etc/shadow
      fi
    '';
  };

  # Garante que o script 'users' espere o 'restoreShadow' concluir,
  # de modo que ele leia o /etc/shadow restaurado e preserve as senhas.
  system.activationScripts.users.deps = [ "restoreShadow" ];

  systemd = {
    # Permissão de escrita em /etc/nixos para o grupo wheel.
    # O diretório real fica em /persist/etc/nixos (bind mount via impermanence).
    # A regra 'z' ajusta dono e modo sem apagar o conteúdo existente.
    tmpfiles.rules = [ "z /persist/etc/nixos 0775 root wheel - -" ];

    # Monitora /etc/shadow e persiste toda alteração em /persist/etc/shadow.
    # PathChanged captura IN_MOVED_TO (rename atômico do 'passwd'/'chage'/'users')
    # bem como IN_CLOSE_WRITE (escrita direta). O serviço é oneshot e idempotente.
    paths.persistShadow = {
      description = "Monitorar /etc/shadow para persistir alterações de senha";
      wantedBy = [ "multi-user.target" ];
      pathConfig = {
        PathChanged = "/etc/shadow";
        Unit = "persistShadow.service";
      };
    };

    services = {
      persistShadow = {
        description = "Persistir /etc/shadow em /persist/etc/shadow";
        serviceConfig = {
          Type = "oneshot";
        };
        script = ''
          mkdir -p /persist/etc
          if [ -f /etc/shadow ]; then
            ${pkgs.coreutils}/bin/install -m 640 /etc/shadow /persist/etc/shadow
          fi
        '';
      };

      # Força a troca de senha no primeiro login para usuários com initialPassword/initialHashedPassword.
      # Usa um arquivo de flag em /persist para que a troca seja exigida apenas uma vez.
      #
      # Inicia após 'persistShadow.path' (acima), garantindo que o monitor inotify já
      # esteja ativo quando 'chage -d 0' modifica /etc/shadow. Assim a alteração é
      # imediatamente copiada para /persist/etc/shadow pelo persistShadow.service.
      #
      # Para redefinir: apague /persist/.password-change-required-<usuario> e reinicie.
      forceInitialPasswordChange = lib.mkIf (usersWithInitialPassword != { }) {
        description = "Forçar troca de senha no primeiro login (usuários com senha inicial)";
        wantedBy = [ "multi-user.target" ];
        after = [
          "local-fs.target"
          "persistShadow.path"
        ];
        wants = [ "persistShadow.path" ];
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
    };
  };
}
