{ pkgs, ... }:
{
  programs.keepassxc = {
    enable = true;

    settings = {
      Browser = {
        Enabled = true;
        UpdateBinaryPath = false; # HM manages the manifest; prevents overwrite on startup
      };
      GUI = {
        ColorPasswords = true;
        MinimizeOnClose = true;
        MinimizeToTray = true;
        MonospaceNotes = true;
        ShowTrayIcon = true;
        TrayIconAppearance = "colorful";
      };
      Security = {
        IconDownloadFallback = true;
        LockDatabaseIdle = false;
      };
      SSHAgent.Enabled = true;
    };

    # Three environment overrides, originally tuned for GNOME/qgnomeplatform,
    # now targeting Umbriel's xdg-desktop-portal-umbriel (falls back to gtk —
    # see programs.umbriel.portalPackage in dendritic/flake/noctalia-wrapper.nix):
    #
    # 1. QT_WAYLAND_DECORATION=adwaita
    #    Draws the client-side title bar via qadwaitadecorations, which
    #    subscribes to org.freedesktop.portal.Settings' SettingChanged signal
    #    and repaints on every light/dark change — desktop-agnostic as long
    #    as the active portal implements org.freedesktop.portal.Settings.
    #
    # 2. QT_PLUGIN_PATH prefixed with qadwaitadecorations
    #    qadwaitadecorations is not a build dependency of keepassxc in
    #    nixpkgs, so its directory isn't part of the QT_PLUGIN_PATH generated
    #    by the Qt wrapper. We need to add it explicitly so Qt can find the plugin.
    #
    # 3. QT_QPA_PLATFORMTHEME=xdgdesktopportal
    #    Delegates file dialogs and color-scheme/font/cursor settings to
    #    whatever implements the corresponding xdg-desktop-portal interfaces,
    #    instead of hardcoding a GTK/GNOME theme backend. Verify after
    #    switching that xdg-desktop-portal-umbriel/gtk cover these — if not,
    #    KeePassXC falls back to Qt's own (non-portal) file dialog and theme.
    package = pkgs.symlinkJoin {
      name = "keepassxc";
      paths = [ pkgs.keepassxc ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/keepassxc \
          --set QT_WAYLAND_DECORATION adwaita \
          --prefix QT_PLUGIN_PATH : ${pkgs.qadwaitadecorations}/lib/qt-${pkgs.qt5.qtbase.version}/plugins \
          --set QT_QPA_PLATFORMTHEME xdgdesktopportal
      '';
    };
  };
}
