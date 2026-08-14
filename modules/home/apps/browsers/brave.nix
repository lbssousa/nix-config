# User module: Brave Browser Flatpak — alternate browser (default: Firefox)
#
# Brave is installed as a Flatpak (com.brave.Browser) — not via programs.brave.
# Extensions (e.g. KeePassXC-Browser) are installed manually.
#
# PWA .desktop fixup: Brave's Flatpak PWA installer (flextop) writes
# .desktop files that violate the freedesktop.org spec and are missing
# StartupNotify/have the wrong StartupWMClass for Wayland window matching
# (see pkgs/fix-brave-pwa-desktop). A systemd path unit watches
# ~/.local/share/applications and reruns the fix whenever Brave
# installs or updates a PWA — the fix itself is idempotent, so repeated
# triggers (including the one caused by the fix writing its own backup
# file) are harmless and self-limiting.
{
  config,
  pkgs,
  lib,
  ...
}:

let
  appsDir = "${config.xdg.dataHome}/applications";
in

{
  home.packages = [ pkgs.fix-brave-pwa-desktop ];

  xdg.configFile = {
    # StartLimitIntervalSec=0 disables systemd's rate limit for this
    # idempotent oneshot service: the path unit can fire more than once
    # in quick succession (e.g. a PWA install writes several files) without
    # triggering 'start-limit-hit'.
    "systemd/user/fix-brave-pwa-desktop.service".text = ''
      [Unit]
      Description=Fixes Brave Flatpak PWA .desktop files
      StartLimitIntervalSec=0

      [Service]
      Type=oneshot
      ExecStart=${pkgs.fix-brave-pwa-desktop}/bin/fix-brave-pwa-desktop
    '';

    "systemd/user/fix-brave-pwa-desktop.path".text = ''
      [Unit]
      Description=Watches for Brave Flatpak PWA installs/updates

      [Path]
      PathChanged=${appsDir}
      Unit=fix-brave-pwa-desktop.service

      [Install]
      WantedBy=default.target
    '';
  };

  home.activation.enableFixBravePwaDesktopUnit = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    systemctlUser=${lib.escapeShellArg "${pkgs.systemd}/bin/systemctl --user"}
    systemdUserWantsDir=${lib.escapeShellArg "${config.xdg.configHome}/systemd/user/default.target.wants"}

    ${pkgs.coreutils}/bin/mkdir -p "$systemdUserWantsDir"

    ${pkgs.coreutils}/bin/ln -sfn ../fix-brave-pwa-desktop.path \
      "$systemdUserWantsDir/fix-brave-pwa-desktop.path"

    # Reload and start units only if there's an active user session.
    # Without a session (e.g. during nixos-rebuild without login), the
    # symlink above is enough: systemd will load the unit via
    # WantedBy=default.target once the session starts.
    if XDG_RUNTIME_DIR="/run/user/$(id -u)" $systemctlUser status >/dev/null 2>&1; then
      $systemctlUser daemon-reload
      $systemctlUser reset-failed \
        fix-brave-pwa-desktop.path \
        fix-brave-pwa-desktop.service || true
      $systemctlUser start \
        fix-brave-pwa-desktop.path
    fi
  '';
}
