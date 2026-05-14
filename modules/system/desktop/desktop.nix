# Módulo de ambiente gráfico: GNOME + Flatpak
{
  pkgs,
  lib,
  ...
}:

let
  flatpaks = [
    # Aplicações de terceiros
    "com.bitwarden.desktop"
    "com.github.PintaProject.Pinta"
    "com.github.tchx84.Flatseal"
    "com.google.Chrome"
    "com.mattjakeman.ExtensionManager"
    "com.obsproject.Studio"
    "com.ranfdev.DistroShelf"
    "io.github.flattool.Ignition"
    "io.github.flattool.Warehouse"
    "io.github.kolunmi.Bazaar"
    "io.gitlab.adhami3310.Impression"
    "it.mijorus.smile"
    # Aplicações GNOME — excluídas do Nix, instaladas via Flatpak para
    # receber atualizações independentes do ciclo de releases do sistema.
    "org.gnome.baobab"
    "org.gnome.Calculator"
    "org.gnome.Calendar"
    "org.gnome.Characters"
    "org.gnome.clocks"
    "org.gnome.Connections"
    "org.gnome.Contacts"
    "org.gnome.Decibels"
    "org.gnome.font-viewer"
    "org.gnome.Logs"
    "org.gnome.Loupe"
    "org.gnome.Maps"
    "org.gnome.Music"
    "org.gnome.Papers"
    "org.gnome.Showtime"
    "org.gnome.SimpleScan"
    "org.gnome.Snapshot"
    "org.gnome.TextEditor"
    "org.gnome.Weather"
    # Temas GTK3 para compatibilidade com apps legados
    "org.gtk.Gtk3theme.adw-gtk3"
    "org.gtk.Gtk3theme.adw-gtk3-dark"
    # Segurança
    "org.keepassxc.KeePassXC"
    "org.kde.kleopatra"
    "page.tesk.Refine"
  ];
in
{
  services = {
    # Flatpak — instalação e reconciliação declarativa via nix-flatpak.
    # onActivation garante reinstalação em cada rebuild; o timer diário protege
    # contra remoções acidentais feitas fora do ciclo de rebuild.
    flatpak = {
      enable = true;
      packages = flatpaks;
      update.onActivation = true;
      update.auto = {
        enable = true;
        onCalendar = "daily";
      };

    };

    # Impressão (CUPS)
    printing.enable = true;

    # Sessão GNOME (Wayland)
    displayManager.gdm = {
      enable = true;
      wayland = true;
    };
    desktopManager.gnome.enable = true;
  };

  # Desabilitar servidor X11 completamente (Wayland-only)
  services.xserver.enable = false;

  # Integrar aplicações Qt ao visual do GNOME.
  qt = {
    enable = true;
    platformTheme = "gnome";
    style = "adwaita";
  };

  environment = {
    variables = {
      # No Wayland, Mutter não fornece decorações do lado do servidor.
      # Forçamos "gnome" para que apps Qt usem libqgnomeplatformdecoration.so,
      # que lê o button-layout de forma síncrona via GnomeSettings e sempre
      # exibe o botão de fechar corretamente.
      #
      # Não usamos "adwaita" porque o plugin qadwaitadecorations (Qt5) e o
      # qadwaitadecorations-qt6 compartilham o mesmo bug: após a chamada D-Bus
      # assíncrona que retorna o button-layout, forceRepaint() não dispara um
      # repaint real no Wayland, e os botões da barra de título ficam invisíveis.
      QT_WAYLAND_DECORATION = "gnome";
    };

    gnome.excludePackages = with pkgs; [
      # Tour de boas-vindas — sem substituto Flatpak
      gnome-tour
      # Navegador Web → substituído pelo Google Chrome (Flatpak)
      # Terminais → substituídos pelo Ptyxis (Nix)
      gnome-console
      gnome-terminal
      # Aplicações GNOME → instaladas via Flatpak (atualizações independentes do sistema)
      baobab # → org.gnome.baobab
      decibels # → org.gnome.Decibels
      gnome-calculator # → org.gnome.Calculator
      gnome-calendar # → org.gnome.Calendar
      gnome-characters # → org.gnome.Characters
      gnome-clocks # → org.gnome.clocks
      gnome-connections # → org.gnome.Connections
      gnome-contacts # → org.gnome.Contacts
      gnome-font-viewer # → org.gnome.font-viewer
      gnome-logs # → org.gnome.Logs
      gnome-maps # → org.gnome.Maps
      gnome-music # → org.gnome.Music
      gnome-software # → substituído pelo Bazaar (Flatpak)
      gnome-text-editor # → org.gnome.TextEditor
      gnome-weather # → org.gnome.Weather
      loupe # → org.gnome.Loupe
      papers # → org.gnome.Papers
      showtime # → org.gnome.Showtime
      simple-scan # → org.gnome.SimpleScan
      snapshot # → org.gnome.Snapshot
      yelp # Ajuda GNOME — sem substituto Flatpak relevante
    ];

    systemPackages = with pkgs; [
      firefox # Navegador padrão do sistema — disponível a todos os usuários
      ptyxis # Terminal moderno para GNOME
      gjs # Motor JavaScript para GNOME (GObject Introspection)
      epiphany # Navegador GNOME Web
    ];

    # Navegador padrão do sistema: Firefox (Nix), disponível a todos os
    # usuários. Usuários que preferirem outro navegador podem sobrescrever
    # via xdg.mimeApps (home-manager) ou gsettings.
    etc."xdg/mimeapps.list".text = ''
      [Default Applications]
      text/html=firefox.desktop
      x-scheme-handler/http=firefox.desktop
      x-scheme-handler/https=firefox.desktop
      x-scheme-handler/about=firefox.desktop
      x-scheme-handler/unknown=firefox.desktop
    '';
  };

  programs.dconf = {
    enable = true;
    # Perfil de sistema: define padrões que valem para todos os usuários
    # (inclusive os que não usam home-manager). Valores de usuário (dconf.settings
    # no HM ou gsettings manual) sobrescrevem estes padrões normalmente.
    profiles.user.databases = [
      {
        settings = {
          "org/gnome/desktop/input-sources" = {
            sources = [
              (lib.gvariant.mkTuple [
                "xkb"
                "br"
              ])
            ];
            mru-sources = [
              (lib.gvariant.mkTuple [
                "xkb"
                "br"
              ])
            ];
            xkb-model = "abnt2";
          };

          # IBus: delega layout ao XKB do sistema (corrige dead keys em apps
          # gráficos) e pré-carrega a engine BR na inicialização da sessão.
          "desktop/ibus/general" = {
            use-system-keyboard-layout = true;
            preload-engines = [ "xkb:br::por" ];
          };

          # Interface visual padrão do GNOME.
          # Fonte ligeiramente maior que o padrão (12 pt vs 11 pt) para melhor
          # legibilidade, e cursor/ícone Adwaita para evitar resquícios do Plasma.
          "org/gnome/desktop/interface" = {
            icon-theme = "Adwaita";
            cursor-theme = "Adwaita";
            cursor-size = lib.gvariant.mkInt32 24;
            font-name = "Adwaita Regular 12";
            monospace-font-name = "Adwaita Mono 12";
            document-font-name = "Adwaita Regular 12";
          };

          # Tema de sons padrão do freedesktop (compatível com GNOME).
          "org/gnome/desktop/sound" = {
            theme-name = "freedesktop";
          };

          # Layout da barra de título: apenas botão de fechar, sem minimizar
          # nem maximizar (padrão GNOME moderno).
          "org/gnome/desktop/wm/preferences" = {
            button-layout = ":close";
          };
        };
      }
    ];
  };

  # Cria ~/.config/ibus/Compose para todos os usuários ao iniciar a sessão,
  # garantindo que o IBus use a tabela de composição do locale do sistema
  # (corrige digitação de ~, ', `, acentos etc.) independentemente do
  # uso de home-manager. A diretiva 'f' só cria o arquivo se ainda não existir,
  # preservando customizações manuais. '%%L' em tmpfiles.d vira '%L' no arquivo
  # final (placeholder de locale do IBus Compose).
  systemd.user.tmpfiles.rules = [
    ''f %h/.config/ibus/Compose 0644 - - - include "%%L"''
  ];

  # Regra Polkit para permitir instalação de Flatpaks system-wide sem senha
  security.polkit.extraConfig = ''
    // Permitir que usuários do grupo 'wheel' gerenciem Flatpaks sem senha
    polkit.addRule(function(action, subject) {
      if (action.id.indexOf("org.freedesktop.Flatpak") === 0 &&
          subject.isInGroup("wheel")) {
        return polkit.Result.YES;
      }
    });
  '';

  # Habilita execução de binários FHS não-patchados (ex.: dev tools distribuídos
  # como binários genéricos Linux). Sem nix-ld, eles falham com "stub-ld" errors.
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc.lib # libstdc++.so.6
      zlib
    ];
  };

  # XDG Portal para integração Flatpak com GNOME
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
  };

  # Bluetooth
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  # Fontes essenciais para o desktop
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      liberation_ttf
      nerd-fonts.adwaita-mono
      nerd-fonts.fira-code
      nerd-fonts.fira-mono
      nerd-fonts.hack
      nerd-fonts.inconsolata
      nerd-fonts.jetbrains-mono
      nerd-fonts.meslo-lg
      nerd-fonts.ubuntu-mono
      nerd-fonts.zed-mono
    ];
    fontconfig = {
      defaultFonts = {
        serif = [ "Noto Serif" ];
        sansSerif = [ "Noto Sans" ];
        monospace = [ "JetBrainsMono Nerd Font" ];
        emoji = [ "Noto Color Emoji" ];
      };
    };
  };
}
