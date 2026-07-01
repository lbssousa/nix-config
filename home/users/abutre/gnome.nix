# Configuração GNOME para o usuário abutre
_:

{
  xdg.mimeApps.defaultApplications = {
    "application/pdf" = "org.gnome.Papers.desktop";
    "application/x-bzpdf" = "org.gnome.Papers.desktop";
    "application/x-gzpdf" = "org.gnome.Papers.desktop";
    "application/x-xzpdf" = "org.gnome.Papers.desktop";
    "application/x-ext-pdf" = "org.gnome.Papers.desktop";
  };

  dconf.settings = {
    # Quake Terminal — usa o perfil sem decorações definido em ghostty.nix
    "org/gnome/shell/extensions/quake-terminal" = {
      terminal-id = "ghostty-no-decorations.desktop";
      terminal-shortcut = [ "F12" ];
      vertical-size = 75;
      skip-taskbar = true;
    };
  };
}
