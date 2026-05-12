# Notificação gráfica GNOME quando o PAM solicita toque na YubiKey.
#
# Insere um pam_exec.so antes do pam_u2f (ordem 10900) no stack de sudo e
# polkit-1. O script descobre o usuário via PAM_RUSER (ou loginuid como
# fallback), verifica se há sessão gráfica em /run/user/<uid>/bus e envia
# uma notificação urgente via org.freedesktop.Notifications (gnome-shell).
# A chamada é feita em background para não bloquear o sudo enquanto aguarda
# a autenticação U2F.
{ pkgs, ... }:

let
  notifyScript = pkgs.writeShellScript "yubikey-touch-notify" ''
    # Determina o usuário que invocou sudo/polkit
    user="''${PAM_RUSER:-}"

    # Fallback: loginuid do processo PAM (útil no polkit onde PAM_RUSER pode
    # estar vazio ou ser "root")
    if [ -z "$user" ] || [ "$user" = "root" ]; then
      loginuid=$(cat /proc/self/loginuid 2>/dev/null || true)
      if [ -n "$loginuid" ] && [ "$loginuid" != "4294967295" ]; then
        user=$(id -nu "$loginuid" 2>/dev/null || true)
      fi
    fi

    [ -n "$user" ] && [ "$user" != "root" ] || exit 0

    uid=$(id -u "$user" 2>/dev/null) || exit 0
    bus="/run/user/$uid/bus"

    # Só notifica se o usuário tiver sessão gráfica ativa
    [ -S "$bus" ] || exit 0

    # Dispara a notificação em background para não bloquear o sudo
    ${pkgs.util-linux}/bin/runuser -u "$user" -- \
      ${pkgs.coreutils}/bin/env \
        DBUS_SESSION_BUS_ADDRESS="unix:path=$bus" \
        XDG_RUNTIME_DIR="/run/user/$uid" \
      ${pkgs.libnotify}/bin/notify-send \
        --app-name="Autenticação" \
        --urgency=critical \
        --icon=security-high-symbolic \
        --expire-time=30000 \
        "Toque na YubiKey" \
        "Autenticação requer toque na chave de segurança." \
      >/dev/null 2>&1 &
  '';
in
{
  security.pam.services.sudo.rules.auth.yubikeyNotify = {
    control = "optional";
    modulePath = "${pkgs.linux-pam}/lib/security/pam_exec.so";
    args = [ "${notifyScript}" ];
    order = 10850; # Imediatamente antes do pam_u2f (order 10900)
  };

  security.pam.services."polkit-1".rules.auth.yubikeyNotify = {
    control = "optional";
    modulePath = "${pkgs.linux-pam}/lib/security/pam_exec.so";
    args = [ "${notifyScript}" ];
    order = 10850;
  };
}
