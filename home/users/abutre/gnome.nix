# Configuração visual e dconf do GNOME para o usuário abutre
{
  config,
  pkgs,
  lib,
  ...
}:

{
  home = {
    packages = [
      pkgs.gnomeExtensions.appindicator
      pkgs.gnomeExtensions.ddterm
    ];

    # Cursor padrão do GNOME — configura Wayland, XWayland e o link ~/.icons/default
    pointerCursor = {
      package = pkgs.adwaita-icon-theme;
      name = "Adwaita";
      size = 24;
      gtk.enable = true;
    };
  };

  xdg.configFile."gtk-3.0/bookmarks" = {
    force = true;
    text = ''
      file://${config.home.homeDirectory}/Documentos
      file://${config.home.homeDirectory}/M%C3%BAsicas
      file://${config.home.homeDirectory}/Imagens
      file://${config.home.homeDirectory}/V%C3%ADdeos
      file://${config.home.homeDirectory}/Downloads
    '';
  };

  dconf.settings = {
    # IBus em Wayland puro: delega layout ao sistema (evita setxkbmap) e
    # carrega a engine BR na inicialização da sessão.
    "desktop/ibus/general" = {
      use-system-keyboard-layout = true;
      preload-engines = [ "xkb:br::por" ];
    };

    "org/gnome/desktop/input-sources" = {
      sources = [
        (lib.hm.gvariant.mkTuple [
          "xkb"
          "br"
        ])
      ];
      mru-sources = [
        (lib.hm.gvariant.mkTuple [
          "xkb"
          "br"
        ])
      ];
      xkb-model = "abnt2";
    };

    # Terminal (Ptyxis)
    "org/gnome/Ptyxis" = {
      use-system-font = false;
      font-name = "JetBrainsMono Nerd Font Mono Regular 14";
    };

    # Interface visual padrão do GNOME (reverter configurações do Plasma)
    "org/gnome/desktop/interface" = {
      # Remove temas residuais do Plasma (Breeze)
      icon-theme = "Adwaita";
      # Fontes padrão do GNOME
      font-name = "Adwaita Regular 12"; # valor padrão: 11
      monospace-font-name = "Adwaita Mono 12"; # valor padrão: 11
      document-font-name = "Adwaita Regular 12"; # valor padrão: 11
    };

    "org/gnome/desktop/sound" = {
      theme-name = "freedesktop";
    };

    # Layout da barra de título: sem ícone de app, sem minimizar/maximizar
    "org/gnome/desktop/wm/preferences" = {
      button-layout = ":close";
    };

    # Extensões GNOME habilitadas
    "org/gnome/shell" = {
      enabled-extensions = [
        "appindicatorsupport@rgcjonas.gmail.com"
        "ddterm@amezin.github.com"
      ];
    };
  };
}
