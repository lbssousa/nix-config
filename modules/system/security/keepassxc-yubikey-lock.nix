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
      keepassxc
      procps
      util-linux
    ];
    text = ''
      set -eu

      username="$1"
      uid="$(id -u "$username")"
      runtime_dir="/run/user/$uid"

      if [ ! -S "$runtime_dir/bus" ]; then
        exit 0
      fi

      if ! pgrep -u "$username" -x keepassxc >/dev/null 2>&1; then
        exit 0
      fi

      if runuser -u "$username" -- env \
        XDG_RUNTIME_DIR="$runtime_dir" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime_dir/bus" \
        gdbus call --session \
          --dest org.keepassxc.KeePassXC.MainWindow \
          --object-path /keepassxc \
          --method org.keepassxc.KeePassXC.MainWindow.lockAllDatabases \
          >/dev/null 2>&1; then
        exit 0
      fi

      runuser -u "$username" -- env \
        XDG_RUNTIME_DIR="$runtime_dir" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime_dir/bus" \
        keepassxc --lock >/dev/null 2>&1
    '';
  };
in
{
  options.security.keepassxc.autoLockOnYubikeyRemove.users = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = ''
      Usuários cujo KeePassXC deve ser trancado quando uma YubiKey for removida.
    '';
  };

  config = lib.mkIf (cfg.users != [ ]) {
    systemd.services."keepassxc-lock-on-yubikey-remove@" = {
      description = "Tranca o KeePassXC na remoção da YubiKey (%i)";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${lib.getExe keepassxcLockOnYubikeyRemove} %i";
      };
    };

    systemd.targets.keepassxc-lock-on-yubikey-remove = {
      description = "Tranca instâncias do KeePassXC após remoção da YubiKey";
      wants = map (user: "keepassxc-lock-on-yubikey-remove@${user}.service") cfg.users;
    };

    services.udev.extraRules = ''
      # Dispara um alvo systemd fora do contexto do udev, para conseguir falar
      # com o barramento D-Bus da sessão dos usuários configurados.
      ACTION=="remove", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="1050", RUN+="${pkgs.systemd}/bin/systemctl --no-block start keepassxc-lock-on-yubikey-remove.target"
    '';
  };
}
