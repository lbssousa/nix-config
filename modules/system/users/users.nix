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
  # PROBLEMA: O script de ativação 'users' do NixOS chama update-users-groups.pl,
  # que substitui atomicamente /etc/shadow via rename(). Isso desfaz qualquer bind
  # mount que o módulo impermanence tenha criado anteriormente. Resultado: alterações
  # de senha via 'passwd' ficam somente no tmpfs e são perdidas no próximo boot.
  #
  # SOLUÇÃO: activation script 'restoreShadow' com deps = ["users"] re-estabelece
  # o bind mount /persist/etc/shadow → /etc/shadow logo após o 'users' activation.
  # Como switch-to-configuration roda ANTES do systemd iniciar (stage-2-init), o
  # bind mount criado aqui persiste durante toda a sessão — incluindo quando o
  # serviço forceInitialPasswordChange executa chage -d 0 (que então escreve no
  # arquivo persistido em /persist/etc/shadow).
  #
  # Ao usar 'passwd', as alterações vão diretamente para /persist/etc/shadow via
  # bind mount, garantindo a persistência entre boots.
  system.activationScripts.restoreShadow = {
    deps = [ "users" ];
    text = ''
      _PERSIST=/persist/etc/shadow
      _SHADOW=/etc/shadow
      mkdir -p /persist/etc

      if [ -f "$_PERSIST" ]; then
        # Mescla as senhas persistidas com o shadow gerenciado pelo NixOS:
        # - Para usuários existentes em ambos: usa a entrada persistida
        #   (preserva senhas alteradas pelo usuário via 'passwd').
        #   Valida o formato mínimo (9 campos separados por ':') antes de usar.
        # - Para usuários novos (ainda não em /persist): usa a entrada do NixOS
        #   (aplica initialPassword da configuração).
        _tmp=$(mktemp)
        while IFS= read -r _line || [ -n "$_line" ]; do
          _user="''${_line%%:*}"
          if _persisted=$(grep "^''${_user}:" "$_PERSIST" 2>/dev/null); then
            # Valida que a entrada persistida tem pelo menos 9 campos (formato shadow)
            _field_count=$(printf '%s' "$_persisted" | awk -F: '{print NF}')
            if [ "''${_field_count:-0}" -ge 9 ]; then
              printf '%s\n' "$_persisted"
            else
              # Formato inválido: usa a entrada gerenciada pelo NixOS como fallback
              printf '%s\n' "$_line"
            fi
          else
            printf '%s\n' "$_line"
          fi
        done < "$_SHADOW" > "$_tmp"
        install -m 640 "$_tmp" "$_PERSIST"
        rm -f "$_tmp"
      else
        # Primeira execução: salva o shadow atual em /persist.
        install -m 640 "$_SHADOW" "$_PERSIST"
      fi

      # Re-estabelece o bind mount /persist/etc/shadow → /etc/shadow.
      # O rename() do update-users-groups.pl pode ter desfeito um bind mount anterior
      # (em nixos-rebuild switch). Recria o mount se não estiver ativo.
      # Usa findmnt (util-linux); se não estiver no PATH, usa awk no /proc/mounts.
      _is_mounted=false
      if findmnt --target "$_SHADOW" > /dev/null 2>&1; then
        # findmnt disponível e detectou mount ativo
        _is_mounted=true
      elif command -v findmnt > /dev/null 2>&1; then
        # findmnt disponível mas não encontrou mount → não montado
        _is_mounted=false
      else
        # findmnt não disponível: usa awk no /proc/mounts como fallback
        if awk -v mnt="$_SHADOW" '$2 == mnt { found=1; exit } END { exit !found }' \
             /proc/mounts 2>/dev/null; then
          _is_mounted=true
        fi
      fi
      if [ "$_is_mounted" = "false" ]; then
        mount --bind "$_PERSIST" "$_SHADOW"
      fi
    '';
  };

  # Força a troca de senha no primeiro login para usuários com initialPassword/initialHashedPassword.
  # Usa um arquivo de flag em /persist para que a troca seja exigida apenas uma vez.
  #
  # O activation script 'restoreShadow' (acima) garante que /etc/shadow esteja
  # bind-mounted em /persist/etc/shadow antes de o systemd iniciar. Portanto,
  # quando este serviço executa 'chage -d 0', ele escreve no arquivo persistido.
  #
  # Para redefinir: apague /persist/.password-change-required-<usuario> e reinicie.
  systemd.services.forceInitialPasswordChange = lib.mkIf (usersWithInitialPassword != { }) {
    description = "Forçar troca de senha no primeiro login (usuários com senha inicial)";
    wantedBy = [ "multi-user.target" ];
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
