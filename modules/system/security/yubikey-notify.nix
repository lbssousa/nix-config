# GNOME desktop notification when PAM asks for a YubiKey touch.
#
# Inserts a pam_exec.so before pam_u2f (order 10900) in the sudo and
# polkit-1 stacks. The script figures out the user via PAM_RUSER (or
# loginuid as a fallback), checks whether there's a graphical session at
# /run/user/<uid>/bus, and sends an urgent notification via
# org.freedesktop.Notifications (gnome-shell). The call runs in the
# background so it doesn't block sudo while waiting for U2F authentication.
{ pkgs, ... }:

let
  notifyScript = pkgs.writeShellScript "yubikey-touch-notify" ''
    # Determine the user who invoked sudo/polkit
    user="''${PAM_RUSER:-}"

    # Fallback: loginuid of the PAM process (useful in polkit, where
    # PAM_RUSER may be empty or "root")
    if [ -z "$user" ] || [ "$user" = "root" ]; then
      loginuid=$(cat /proc/self/loginuid 2>/dev/null || true)
      if [ -n "$loginuid" ] && [ "$loginuid" != "4294967295" ]; then
        user=$(id -nu "$loginuid" 2>/dev/null || true)
      fi
    fi

    [ -n "$user" ] && [ "$user" != "root" ] || exit 0

    uid=$(id -u "$user" 2>/dev/null) || exit 0
    bus="/run/user/$uid/bus"

    # Only notify if the user has an active graphical session
    [ -S "$bus" ] || exit 0

    # Fire the notification in the background so it doesn't block sudo
    ${pkgs.util-linux}/bin/runuser -u "$user" -- \
      ${pkgs.coreutils}/bin/env \
        DBUS_SESSION_BUS_ADDRESS="unix:path=$bus" \
        XDG_RUNTIME_DIR="/run/user/$uid" \
      ${pkgs.libnotify}/bin/notify-send \
        --app-name="Authentication" \
        --urgency=critical \
        --icon=security-high-symbolic \
        --expire-time=30000 \
        "Touch the YubiKey" \
        "Authentication requires a touch on the security key." \
      >/dev/null 2>&1 &
  '';
in
{
  security.pam.services.sudo.rules.auth.yubikeyNotify = {
    control = "optional";
    modulePath = "${pkgs.linux-pam}/lib/security/pam_exec.so";
    # seteuid: runs the script with the effective UID (root) instead of the
    # real UID (the invoking user). Needed so runuser can switch users —
    # without seteuid, pam_exec runs the script as the real user and
    # runuser refuses the call for lack of privilege.
    args = [
      "seteuid"
      "${notifyScript}"
    ];
    order = 10850; # Immediately before pam_u2f (order 10900)
  };

  security.pam.services."polkit-1".rules.auth.yubikeyNotify = {
    control = "optional";
    modulePath = "${pkgs.linux-pam}/lib/security/pam_exec.so";
    args = [
      "seteuid"
      "${notifyScript}"
    ];
    order = 10850;
  };
}
