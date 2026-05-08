# Módulo de ambiente gráfico: GNOME ou KDE Plasma + Flatpak
{
  config,
  pkgs,
  lib,
  ...
}:

let
  inherit (lib) mkIf mkOption types;
  cfg = config.my.desktop;

  # Flatpaks comuns do sistema
  commonFlatpaks = [
    "com.bitwarden.desktop"
    "com.github.PintaProject.Pinta"
    "com.github.tchx84.Flatseal"
    "com.ranfdev.DistroShelf"
    "io.github.flattool.Ignition"
    "io.github.flattool.Warehouse"
    "io.gitlab.adhami3310.Impression"
    "it.mijorus.smile"
    "org.gtk.Gtk3theme.adw-gtk3"
    "org.gtk.Gtk3theme.adw-gtk3-dark"
    "page.tesk.Refine"
  ];

  # Flatpaks específicos para GNOME
  gnomeFlatpaks = [
    "com.mattjakeman.ExtensionManager"
    "io.github.kolunmi.Bazaar"
  ];

  # Flatpaks específicos para KDE Plasma
  plasmaFlatpaks = [
    "org.kde.filelight"
    "org.kde.gwenview"
    "org.kde.kate"
    "org.kde.kcalc"
    "org.kde.kcharselect"
    "org.kde.konsole"
    "org.kde.okular"
    "org.kde.skanpage"
  ];
in
{
  options.my.desktop.environment = mkOption {
    type = types.enum [
      "gnome"
      "plasma"
    ];
    default = "plasma";
    description = "Desktop environment to enable for this host.";
  };

  config = {
    services = {
      # Flatpak - instalação system-wide via nix-flatpak
      flatpak = {
        enable = true;
        packages =
          commonFlatpaks
          ++ lib.optionals (cfg.environment == "gnome") gnomeFlatpaks
          ++ lib.optionals (cfg.environment == "plasma") plasmaFlatpaks;
      };

      # Impressão (CUPS)
      printing.enable = true;
    };

    # Sessão GNOME (Wayland)
    services.displayManager.gdm = mkIf (cfg.environment == "gnome") {
      enable = true;
      wayland = true;
    };
    services.desktopManager.gnome.enable = mkIf (cfg.environment == "gnome") true;

    # Integrar aplicações Qt ao visual do GNOME.
    qt = mkIf (cfg.environment == "gnome") {
      enable = true;
      platformTheme = "gnome";
      style = "adwaita";
    };

    environment = {
      variables = mkIf (cfg.environment == "gnome") {
        # No Wayland, Mutter não fornece decorações do lado do servidor.
        # Forçamos a decoração "gnome" para que apps Qt usem o plugin
        # libqgnomeplatformdecoration.so (do qgnomeplatform, já instalado via
        # qt.platformTheme = "gnome"), que lê o button-layout de forma síncrona
        # via GnomeSettings e sempre exibe o botão de fechar corretamente.
        #
        # Não usamos "adwaita" porque o plugin qadwaitadecorations (Qt5) e o
        # qadwaitadecorations-qt6 compartilham o mesmo bug: após a chamada D-Bus
        # assíncrona que retorna o button-layout, forceRepaint() não dispara um
        # repaint real no Wayland, e os botões da barra de título ficam invisíveis.
        QT_WAYLAND_DECORATION = "gnome";
      };

      # Excluir pacotes padrão do GNOME que serão substituídos por pacotes Nix
      gnome.excludePackages = mkIf (cfg.environment == "gnome") (
        with pkgs;
        [
          gnome-tour
          epiphany # Browser padrão do GNOME — usar Google Chrome (Nix)
          gnome-console # Terminal (kgx) — usar Ptyxis (Nix)
          gnome-terminal # Terminal legado — usar Ptyxis (Nix)
          gnome-music
        ]
      );

      # Google Chrome e terminal instalados via Nix
      systemPackages =
        with pkgs;
        [
          google-chrome # Navegador padrão
        ]
        ++ lib.optionals (cfg.environment == "gnome") [
          ptyxis # Terminal moderno no GNOME
          gjs # Motor JavaScript para GNOME (GObject Introspection)
        ];
    };

    # Sessão KDE Plasma
    services.displayManager.plasma-login-manager = mkIf (cfg.environment == "plasma") {
      enable = true;
    };
    services.desktopManager.plasma6.enable = mkIf (cfg.environment == "plasma") true;

    # Wayland-only: desabilitar servidor X11 (Xorg) completamente
    services.xserver.enable = false;

    programs.dconf = mkIf (cfg.environment == "gnome") {
      enable = true;
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
          };
        }
      ];
    };

    # Regra Polkit para permitir instalação de Flatpaks system-wide sem senha
    # Similar ao comportamento do Fedora Silverblue
    security.polkit.extraConfig = ''
      // Permitir que usuários do grupo 'wheel' gerenciem Flatpaks sem senha
      polkit.addRule(function(action, subject) {
        if (action.id.indexOf("org.freedesktop.Flatpak") === 0 &&
            subject.isInGroup("wheel")) {
          return polkit.Result.YES;
        }
      });
    '';

    # Enable running unpatched FHS binaries such as wasi-sdk (downloaded by
    # Zed to compile tree-sitter grammars). Without nix-ld, dynamically linked
    # executables intended for generic Linux fail with "stub-ld" errors.
    programs.nix-ld = {
      enable = true;
      # Minimum libraries required by wasi-sdk's clang and typical dev tools.
      libraries = with pkgs; [
        stdenv.cc.cc.lib # libstdc++.so.6
        zlib
      ];
    };

    # XDG Portal para integração Flatpak com o DE selecionado
    xdg.portal = {
      enable = true;
      extraPortals =
        if cfg.environment == "gnome" then
          [ pkgs.xdg-desktop-portal-gnome ]
        else
          [ pkgs.kdePackages.xdg-desktop-portal-kde ];
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
  };
}
