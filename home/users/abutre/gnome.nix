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

  # Nota: configurações dconf não são declaradas aqui com dconf.settings.
  # Com home efêmero, dconf.settings escreve em ~/.config/dconf/user apenas
  # no home-manager switch — perdendo-se no próximo reboot.
  # Declarar em programs.dconf.profiles.*.databases no NixOS (ver gnome-wrapper.nix).
}
