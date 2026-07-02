# Módulo de usuário: Bitwarden Flatpak com agente SSH
#
# Configura SSH_AUTH_SOCK apontando para o socket do agente SSH do Bitwarden
# em duas camadas complementares:
#
#   1. environment.d — lido pelo systemd --user na inicialização da sessão;
#      herdado por GNOME Shell, VSCode, Zed e todos os processos filhos,
#      inclusive antes de o Bitwarden abrir pela primeira vez.
#
#   2. path unit systemd — observa o socket e, ao detectá-lo, atualiza
#      SSH_AUTH_SOCK via `systemctl --user set-environment`; garante que
#      processos já em execução recebam o valor correto quando o socket
#      aparece durante a sessão.
#
# Caminho do socket (Flatpak):
#   $HOME/.var/app/com.bitwarden.desktop/data/.bitwarden-ssh-agent.sock
{
  config,
  pkgs,
  lib,
  ...
}:

let
  sock = "${config.home.homeDirectory}/.var/app/com.bitwarden.desktop/data/.bitwarden-ssh-agent.sock";

  # O Bitwarden Flatpak escreve --command=bitwarden.sh no arquivo de autostart,
  # o que quebra a inicialização da sessão. Este script corrige para --command=bitwarden
  # sempre que o arquivo for criado ou modificado pelo Flatpak.
  fixBitwardenAutostart = pkgs.writeShellScript "fix-bitwarden-autostart" ''
    set -euo pipefail
    AUTOSTART_DIR="''${XDG_CONFIG_HOME:-$HOME/.config}/autostart"
    DESKTOP_FILE="$AUTOSTART_DIR/com.bitwarden.desktop.desktop"
    WRONG="flatpak run --command=bitwarden.sh com.bitwarden.desktop"
    RIGHT="flatpak run --command=bitwarden com.bitwarden.desktop"

    if [[ ! -f "$DESKTOP_FILE" ]]; then
      echo "Nenhum autostart do Bitwarden encontrado em: $DESKTOP_FILE"
      exit 0
    fi

    if grep -qF "$RIGHT" "$DESKTOP_FILE"; then
      echo "Autostart já está correto."
      exit 0
    fi

    if grep -qF "$WRONG" "$DESKTOP_FILE"; then
      cp "$DESKTOP_FILE" "$DESKTOP_FILE.bak.$(date +%Y%m%d-%H%M%S)"
      sed -i "s|$WRONG|$RIGHT|" "$DESKTOP_FILE"
      echo "Corrigido: $DESKTOP_FILE"
      exit 0
    fi

    echo "Aviso: conteúdo inesperado em $DESKTOP_FILE"
    cat "$DESKTOP_FILE"
    exit 1
  '';
in

{
  xdg.configFile = {
    # Camada 1 — ambiente estático herdado por todos os processos da sessão.
    "environment.d/20-bitwarden-ssh-agent.conf".text = ''
      SSH_AUTH_SOCK=${sock}
    '';

    # StartLimitIntervalSec=0 desabilita o rate-limit do systemd para estes
    # serviços oneshot idempotentes: o path unit pode disparar mais de uma
    # vez durante o boot/ativação do HM sem causar 'start-limit-hit'.
    "systemd/user/bitwarden-ssh-agent-env.service".text = ''
      [Unit]
      Description=Exporta SSH_AUTH_SOCK do Bitwarden para a sessão systemd
      StartLimitIntervalSec=0

      [Service]
      Type=oneshot
      RemainAfterExit=yes
      ExecStart=${pkgs.systemd}/bin/systemctl --user set-environment SSH_AUTH_SOCK=${sock}
      ExecStop=${pkgs.systemd}/bin/systemctl --user unset-environment SSH_AUTH_SOCK
    '';

    "systemd/user/bitwarden-ssh-agent.path".text = ''
      [Unit]
      Description=Observa o socket do agente SSH do Bitwarden (Flatpak)

      [Path]
      PathExists=${sock}
      Unit=bitwarden-ssh-agent-env.service

      [Install]
      WantedBy=default.target
    '';

    "systemd/user/bitwarden-fix-autostart.service".text = ''
      [Unit]
      Description=Corrige --command=bitwarden.sh para --command=bitwarden no autostart
      StartLimitIntervalSec=0

      [Service]
      Type=oneshot
      ExecStart=${fixBitwardenAutostart}
    '';

    "systemd/user/bitwarden-fix-autostart.path".text = ''
      [Unit]
      Description=Corrige o autostart do Bitwarden quando o Flatpak o reescreve

      [Path]
      PathModified=${config.xdg.configHome}/autostart/com.bitwarden.desktop.desktop
      Unit=bitwarden-fix-autostart.service

      [Install]
      WantedBy=default.target
    '';
  };

  # Fallback para shells que não herdam o ambiente do systemd --user
  # (ex.: sessões SSH ou abertas via `su`).
  programs.zsh.initContent = lib.mkAfter ''
    [[ -S "${sock}" ]] && export SSH_AUTH_SOCK="${sock}"
  '';

  home.activation.enableBitwardenUnits = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    systemctlUser=${lib.escapeShellArg "${pkgs.systemd}/bin/systemctl --user"}
    systemdUserWantsDir=${lib.escapeShellArg "${config.xdg.configHome}/systemd/user/default.target.wants"}

    ${pkgs.coreutils}/bin/mkdir -p "$systemdUserWantsDir"

    ${pkgs.coreutils}/bin/ln -sfn ../bitwarden-ssh-agent.path \
      "$systemdUserWantsDir/bitwarden-ssh-agent.path"
    ${pkgs.coreutils}/bin/ln -sfn ../bitwarden-fix-autostart.path \
      "$systemdUserWantsDir/bitwarden-fix-autostart.path"

    # Recarregar e iniciar units apenas se há sessão de usuário ativa.
    # Sem sessão (ex.: durante nixos-rebuild sem login), os symlinks acima são
    # suficientes: systemd carregará as units via WantedBy=default.target ao iniciar a sessão.
    if XDG_RUNTIME_DIR="/run/user/$(id -u)" $systemctlUser status >/dev/null 2>&1; then
      $systemctlUser daemon-reload
      $systemctlUser reset-failed \
        bitwarden-ssh-agent.path \
        bitwarden-ssh-agent-env.service \
        bitwarden-fix-autostart.path \
        bitwarden-fix-autostart.service || true
      $systemctlUser start \
        bitwarden-ssh-agent.path \
        bitwarden-fix-autostart.path
    fi
  '';
}
