# Configuração visual e dconf do GNOME para o usuário abutre
{
  config,
  pkgs,
  ...
}:

{
  imports = [
    ../../../modules/home/apps/terminals/ghostty.nix
  ];

  home = {
    packages = [
      pkgs.gnomeExtensions.appindicator
      pkgs.gnomeExtensions.caffeine
      pkgs.gnomeExtensions.quake-terminal
      pkgs.ghostty
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
    # Terminal (Ptyxis)
    "org/gnome/Ptyxis" = {
      use-system-font = false;
      font-name = "JetBrainsMono Nerd Font Mono Regular 14";
    };

    # Extensões GNOME habilitadas
    "org/gnome/shell" = {
      enabled-extensions = [
        "appindicatorsupport@rgcjonas.gmail.com"
        "caffeine@patapon.info"
        "quake-terminal@diegodario88.github.io"
      ];
    };

    # Quake Terminal
    "org/gnome/shell/extensions/quake-terminal" = {
      terminal-id = "com.mitchellh.ghostty.desktop";
      terminal-shortcut = [ "F12" ];
      vertical-size = 75;
      skip-taskbar = true;
    };
  };
}
