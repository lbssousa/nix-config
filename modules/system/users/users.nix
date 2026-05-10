# Módulo de usuários: Esqueleto para definição de usuários
# Os arquivos de usuário ficam em users/ (público — contêm apenas pseudônimos)
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

  # Os usuários são definidos em arquivos separados em users/
  # Exemplo: users/abutre.nix
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

  # Migra UIDs para a ordem definida em nomes.csv (abutre=1000, surubi=1001, …).
  #
  # O script 'users' do NixOS (update-users-groups.pl) ignora silenciosamente
  # mudanças de UID em usuários já existentes em /etc/passwd — ele preserva o
  # UID antigo e imprime apenas um aviso. Por isso, é necessário atualizar
  # /etc/passwd ANTES que o script 'users' o leia. Fazemos isso diretamente via
  # sed (sem usermod, que rejeitaria a operação enquanto o usuário tem processos
  # ativos). Após a migração, o uid-map do NixOS é atualizado para que futuras
  # execuções do script 'users' não tentem realocar os UIDs recém-migrados.
  system.activationScripts.migrateUserIds = {
    deps = [ "etc" "restoreShadow" ];
    text = ''
      passwd_file="/etc/passwd"
      uid_map_file="/var/lib/nixos/uid-map"

      migrate_uid() {
        local user="$1" old_uid="$2" new_uid="$3"
        # Só migra se o usuário ainda tem o UID antigo em /etc/passwd.
        if grep -q "^''${user}:x:''${old_uid}:" "$passwd_file" 2>/dev/null; then
          echo "migrateUserIds: ''${user} ''${old_uid} → ''${new_uid}"
          sed -i "s|^''${user}:x:''${old_uid}:|''${user}:x:''${new_uid}:|" "$passwd_file"
          # Atualiza o uid-map para que o NixOS não tente realocar este UID.
          if [ -f "$uid_map_file" ]; then
            tmp="$(mktemp)"
            python3 -c "
import json, sys
m = json.load(open('$uid_map_file'))
m['$user'] = $new_uid
print(json.dumps(m, sort_keys=True, indent=4))
" > "$tmp" && mv "$tmp" "$uid_map_file"
          fi
        fi
      }

      # Ordem calculada para que o novo UID já esteja livre no momento
      # em que é atribuído (evita colisões transitórias em /etc/passwd).
      migrate_uid abutre  1006 1000  # ← livre imediatamente
      migrate_uid surubi  1013 1001
      migrate_uid coruja  1010 1002
      migrate_uid camelo  1007 1003  # libera 1007 para coelho
      migrate_uid cavalo  1008 1004
      migrate_uid macaco  1012 1005
      migrate_uid gorila  1011 1006  # 1006 livre após abutre migrar
      migrate_uid coelho  1009 1007  # 1007 livre após camelo migrar
    '';
  };

  # Garante que o script 'users' espere o 'restoreShadow' e o 'migrateUserIds'
  # concluírem, de modo que ele leia o /etc/shadow e /etc/passwd já atualizados.
  system.activationScripts.users.deps = [ "restoreShadow" "migrateUserIds" ];

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
