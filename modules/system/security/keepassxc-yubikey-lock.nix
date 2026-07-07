{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.security.keepassxc.autoLockOnYubikeyRemove;

  keepassxcLockOnYubikeyRemove = pkgs.writeShellApplication {
    name = "keepassxc-lock-on-yubikey-remove";
    runtimeInputs = with pkgs; [
      coreutils
      glib
      util-linux
    ];
    text = ''
      set -eu

      username="$1"
      uid="$(id -u "$username")"
      runtime_dir="/run/user/$uid"
      keepassxc_dbus_name="org.keepassxc.KeePassXC.MainWindow"

      if [ ! -S "$runtime_dir/bus" ]; then
        exit 0
      fi

      has_owner="$(
        runuser -u "$username" -- env \
          XDG_RUNTIME_DIR="$runtime_dir" \
          DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime_dir/bus" \
          gdbus call --session \
            --dest org.freedesktop.DBus \
            --object-path /org/freedesktop/DBus \
            --method org.freedesktop.DBus.NameHasOwner \
            "$keepassxc_dbus_name" \
            2>/dev/null || true
      )"

      case "$has_owner" in
        *"(true,"*) ;;
        *)
          exit 0
          ;;
      esac

      runuser -u "$username" -- env \
        XDG_RUNTIME_DIR="$runtime_dir" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime_dir/bus" \
        gdbus call --session \
          --dest "$keepassxc_dbus_name" \
          --object-path /keepassxc \
          --method org.keepassxc.KeePassXC.MainWindow.lockAllDatabases \
          >/dev/null 2>&1 || true
    '';
  };

  keepassxcLockOnYubikeyRemoveAll = pkgs.writeShellApplication {
    name = "keepassxc-lock-on-yubikey-remove-all";
    runtimeInputs = [ keepassxcLockOnYubikeyRemove ];
    text = ''
      set -eu

      for username in "$@"; do
        keepassxc-lock-on-yubikey-remove "$username"
      done
    '';
  };
in
{
  options.security.keepassxc.autoLockOnYubikeyRemove.users = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = ''
      Users whose KeePassXC should be locked when a YubiKey is removed.
    '';
  };

  config = lib.mkIf (cfg.users != [ ]) {
    services.udev.extraRules = ''
      # On "remove" events, derived properties like ID_VENDOR_ID may no
      # longer be available. The raw PRODUCT field is still present and is
      # the most reliable identifier for recognizing the YubiKey on removal.
      ACTION=="remove", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ENV{PRODUCT}=="1050/407/*", RUN+="${pkgs.systemd}/bin/systemd-run --no-block --quiet --collect --service-type=oneshot ${lib.getExe keepassxcLockOnYubikeyRemoveAll} ${lib.escapeShellArgs cfg.users}"
    '';
  };
}
