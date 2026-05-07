{ lib, pkgs, ... }:

let
  keepassxcYubikeyWatcher = pkgs.writeShellApplication {
    name = "keepassxc-yubikey-lock-watcher";
    runtimeInputs = with pkgs; [
      coreutils
      glib
      gnugrep
      gnused
      keepassxc
      procps
      yubikey-manager
    ];
    text = ''
            set -eu

            list_serials() {
              local output

              if ! output="$(ykman list --serials 2>&1)"; then
                printf '%s\n' "keepassxc-yubikey-lock-watcher: falha ao consultar a YubiKey: $output" >&2
                return 1
              fi

              printf '%s\n' "$output" | sed '/^[[:space:]]*$/d' | LC_ALL=C sort -u
            }

            serial_removed() {
              local old_serials="$1"
              local new_serials="$2"
              local serial

              [ -n "$old_serials" ] || return 1

              while IFS= read -r serial; do
                [ -n "$serial" ] || continue

                if ! printf '%s\n' "$new_serials" | grep -Fxq -- "$serial"; then
                  return 0
                fi
              done <<EOF
      $old_serials
      EOF

              return 1
            }

            lock_keepassxc() {
              if ! pgrep -x keepassxc >/dev/null 2>&1; then
                return 0
              fi

              if gdbus call --session \
                --dest org.keepassxc.KeePassXC.MainWindow \
                --object-path /keepassxc \
                --method org.keepassxc.KeePassXC.MainWindow.lockAllDatabases \
                >/dev/null 2>&1; then
                printf '%s\n' "keepassxc-yubikey-lock-watcher: KeePassXC trancado após remoção da YubiKey."
                return 0
              fi

              if keepassxc --lock >/dev/null 2>&1; then
                printf '%s\n' "keepassxc-yubikey-lock-watcher: KeePassXC trancado após remoção da YubiKey."
                return 0
              fi

              printf '%s\n' "keepassxc-yubikey-lock-watcher: falha ao trancar o KeePassXC após remoção da YubiKey." >&2
              return 1
            }

            if ! previous_serials="$(list_serials)"; then
              previous_serials=""
            fi

            while true; do
              sleep 2

              if ! current_serials="$(list_serials)"; then
                continue
              fi

              if serial_removed "$previous_serials" "$current_serials"; then
                if ! lock_keepassxc; then
                  :
                fi
              fi

              previous_serials="$current_serials"
            done
    '';
  };
in
{
  programs.keepassxc.enable = true;

  systemd.user.services.keepassxc-yubikey-lock-watcher = {
    Unit = {
      Description = "Tranca o KeePassXC quando a YubiKey for removida";
    };

    Service = {
      ExecStart = lib.getExe keepassxcYubikeyWatcher;
      Restart = "always";
      RestartSec = 5;
    };

    Install.WantedBy = [ "default.target" ];
  };
}
