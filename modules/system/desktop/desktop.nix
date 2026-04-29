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
    "io.missioncenter.MissionCenter"
    "it.mijorus.smile"
    "org.gtk.Gtk3theme.adw-gtk3"
    "org.gtk.Gtk3theme.adw-gtk3-dark"
    "page.tesk.Refine"
  ];

  # Flatpaks específicos para GNOME
  gnomeFlatpaks = [
    "com.mattjakeman.ExtensionManager"
    "io.github.kolunmi.Bazaar"
    "org.gnome.Calculator"
    "org.gnome.Calendar"
    "org.gnome.Characters"
    "org.gnome.Connections"
    "org.gnome.Contacts"
    "org.gnome.DejaDup"
    "org.gnome.FileRoller"
    "org.gnome.Firmware"
    "org.gnome.Logs"
    "org.gnome.Loupe"
    "org.gnome.Maps"
    "org.gnome.NautilusPreviewer"
    "org.gnome.Papers"
    "org.gnome.Showtime"
    "org.gnome.SimpleScan"
    "org.gnome.Snapshot"
    "org.gnome.SoundRecorder"
    "org.gnome.TextEditor"
    "org.gnome.Weather"
    "org.gnome.baobab"
    "org.gnome.clocks"
    "org.gnome.font-viewer"
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

      # Bluetooth
      blueman.enable = true;

      # Impressão (CUPS)
      printing.enable = true;
    };

    # Sessão GNOME (Wayland)
    services.displayManager.gdm = mkIf (cfg.environment == "gnome") {
      enable = true;
      wayland = true;
    };
    services.desktopManager.gnome.enable = mkIf (cfg.environment == "gnome") true;

    # Sessão KDE Plasma
    services.displayManager.plasma-login-manager = mkIf (cfg.environment == "plasma") {
      enable = true;
    };
    services.desktopManager.plasma6.enable = mkIf (cfg.environment == "plasma") true;

    # Excluir pacotes padrão do GNOME que serão substituídos por Nix ou Flatpaks
    environment.gnome.excludePackages = mkIf (cfg.environment == "gnome") (
      with pkgs;
      [
        gnome-software # Substituído pelo Bazaar (Flatpak)
        gnome-tour
        epiphany # Browser padrão do GNOME — usar Brave (Nix)
        evince # PDF viewer — usar Papers (Flatpak)
        gnome-console # Terminal (kgx) — usar Ptyxis (Nix)
        gnome-terminal # Terminal legado — usar Ptyxis (Nix)
        totem # Player de vídeo — usar Showtime (Flatpak)
        cheese # Webcam app — usar Snapshot (Flatpak)
        snapshot # Câmera — usar Snapshot (Flatpak)
        loupe # Visualizador de imagens — usar Loupe (Flatpak)
        gnome-music
        gnome-maps # Substituído pelo Maps (Flatpak)
        gnome-weather # Substituído pelo Weather (Flatpak)
        gnome-contacts # Substituído pelo Contacts (Flatpak)
        gnome-calendar # Substituído pelo Calendar (Flatpak)
        gnome-clocks # Substituído pelo Clocks (Flatpak)
        gnome-calculator # Substituído pelo Calculator (Flatpak)
        gnome-characters # Substituído pelo Characters (Flatpak)
        gnome-connections # Substituído pelo Connections (Flatpak)
        gnome-logs # Substituído pelo Logs (Flatpak)
        gnome-system-monitor # Substituído pelo Mission Center (Flatpak)
        gnome-text-editor # Substituído pelo Text Editor (Flatpak)
        gnome-font-viewer # Substituído pelo Font Viewer (Flatpak)
        gnome-sound-recorder # Substituído pelo Sound Recorder (Flatpak)
        simple-scan # Substituído pelo Simple Scan (Flatpak)
        baobab # Analisador de disco — usar Baobab (Flatpak)
      ]
    );

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

    # XDG Portal para integração Flatpak com o DE selecionado
    xdg.portal = {
      enable = true;
      extraPortals =
        if cfg.environment == "gnome" then
          [ pkgs.xdg-desktop-portal-gnome ]
        else
          [ pkgs.kdePackages.xdg-desktop-portal-kde ];
    };

    # Aplicar fonte de entrada do GNOME globalmente
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
            };
          };
        }
      ];
    };

    # Bluetooth
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
    };

    # Brave e terminal instalados via Nix
    environment.systemPackages =
      with pkgs;
      [
        brave # Navegador padrão
      ]
      ++ lib.optionals (cfg.environment == "gnome") [
        ptyxis # Terminal moderno no GNOME
      ];

    # Definir Brave como browser padrão via xdg-mime
    xdg.mime.defaultApplications = {
      "text/html" = "brave-browser.desktop";
      "x-scheme-handler/http" = "brave-browser.desktop";
      "x-scheme-handler/https" = "brave-browser.desktop";
      "x-scheme-handler/about" = "brave-browser.desktop";
      "x-scheme-handler/unknown" = "brave-browser.desktop";
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
