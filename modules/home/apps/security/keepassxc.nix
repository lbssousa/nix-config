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

    # Three environment overrides are needed for proper GNOME integration:
    #
    # 1. QT_WAYLAND_DECORATION=adwaita
    #    The qgnomeplatform 0.8.4 plugin (system default via
    #    QT_WAYLAND_DECORATION=gnome) sets decoration colors once in its
    #    constructor and doesn't watch for changes to
    #    org.gnome.desktop.interface.color-scheme. The qadwaitadecorations
    #    plugin subscribes to org.freedesktop.portal.Settings' SettingChanged
    #    signal and calls updateColors() + forceRepaint() on every change,
    #    keeping the title bar in sync with the system's light/dark mode.
    #
    # 2. QT_PLUGIN_PATH prefixed with qadwaitadecorations
    #    qadwaitadecorations is not a build dependency of keepassxc in
    #    nixpkgs, so its directory isn't part of the QT_PLUGIN_PATH generated
    #    by the Qt wrapper. We need to add it explicitly so Qt can find the plugin.
    #
    # 3. QT_QPA_PLATFORMTHEME=xdgdesktopportal
    #    The "gnome" theme (qgnomeplatform, system default) opens file
    #    dialogs as GTK3 widgets inside the KeePassXC process. This causes
    #    two problems:
    #    (a) gtk-application-prefer-dark-theme in settings.ini forces dark
    #        mode regardless of GNOME's current color-scheme;
    #    (b) toggling light/dark while the dialog is open makes GTK3 reload
    #        the theme via inotify, and the active render causes a segfault.
    #    With xdgdesktopportal, the file dialog is delegated to the GNOME
    #    portal, which runs in a separate process and always reflects the
    #    correct system mode. For fonts, cursor and other integrations,
    #    xdgdesktopportal delegates to the underlying "gnome" theme
    #    (determined by XDG_CURRENT_DESKTOP=GNOME).
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
