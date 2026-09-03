# User module: Bitwarden Flatpak with SSH agent
#
# Sets SSH_AUTH_SOCK pointing to Bitwarden's SSH agent socket in two
# complementary layers:
#
#   1. environment.d — read by systemd --user at session startup;
#      inherited by Noctalia Shell, VSCode, Zed and all child processes,
#      even before Bitwarden opens for the first time.
#
#   2. systemd path unit — watches the socket and, once detected, updates
#      SSH_AUTH_SOCK via `systemctl --user set-environment`; ensures
#      already-running processes get the correct value once the socket
#      appears during the session.
#
# Socket path (Flatpak):
#   $HOME/.var/app/com.bitwarden.desktop/data/.bitwarden-ssh-agent.sock
{
  config,
  pkgs,
  lib,
  ...
}:

let
  sock = "${config.home.homeDirectory}/.var/app/com.bitwarden.desktop/data/.bitwarden-ssh-agent.sock";
in

{
  xdg.configFile = {
    # Layer 1 — static environment inherited by all session processes.
    "environment.d/20-bitwarden-ssh-agent.conf".text = ''
      SSH_AUTH_SOCK=${sock}
    '';

    # StartLimitIntervalSec=0 disables systemd's rate limit for these
    # idempotent oneshot services: the path unit can fire more than once
    # during boot/HM activation without triggering 'start-limit-hit'.
    "systemd/user/bitwarden-ssh-agent-env.service".text = ''
      [Unit]
      Description=Exports Bitwarden's SSH_AUTH_SOCK to the systemd session
      StartLimitIntervalSec=0

      [Service]
      Type=oneshot
      RemainAfterExit=yes
      ExecStart=${pkgs.systemd}/bin/systemctl --user set-environment SSH_AUTH_SOCK=${sock}
      ExecStop=${pkgs.systemd}/bin/systemctl --user unset-environment SSH_AUTH_SOCK
    '';

    "systemd/user/bitwarden-ssh-agent.path".text = ''
      [Unit]
      Description=Watches Bitwarden's SSH agent socket (Flatpak)

      [Path]
      PathExists=${sock}
      Unit=bitwarden-ssh-agent-env.service

      [Install]
      WantedBy=default.target
    '';

  };

  # Fallback for shells that don't inherit the systemd --user environment
  # (e.g. SSH sessions or ones opened via `su`).
  programs.zsh.initContent = lib.mkAfter ''
    [[ -S "${sock}" ]] && export SSH_AUTH_SOCK="${sock}"
  '';

  programs.fish.interactiveShellInit = lib.mkAfter ''
    test -S "${sock}"; and set -gx SSH_AUTH_SOCK "${sock}"
  '';

  home.activation.enableBitwardenUnits = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    systemctlUser=${lib.escapeShellArg "${pkgs.systemd}/bin/systemctl --user"}
    systemdUserWantsDir=${lib.escapeShellArg "${config.xdg.configHome}/systemd/user/default.target.wants"}

    ${pkgs.coreutils}/bin/mkdir -p "$systemdUserWantsDir"

    ${pkgs.coreutils}/bin/ln -sfn ../bitwarden-ssh-agent.path \
      "$systemdUserWantsDir/bitwarden-ssh-agent.path"

    # Reload and start units only if there's an active user session.
    # Without a session (e.g. during nixos-rebuild without login), the
    # symlinks above are enough: systemd will load the units via
    # WantedBy=default.target once the session starts.
    if XDG_RUNTIME_DIR="/run/user/$(id -u)" $systemctlUser status >/dev/null 2>&1; then
      $systemctlUser daemon-reload
      $systemctlUser reset-failed \
        bitwarden-ssh-agent.path \
        bitwarden-ssh-agent-env.service || true
      $systemctlUser start \
        bitwarden-ssh-agent.path
    fi
  '';
}
