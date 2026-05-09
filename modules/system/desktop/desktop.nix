# Módulo de ambiente gráfico: GNOME + Flatpak
{
  pkgs,
  lib,
  ...
}:

let
  flatpaks = [
    "com.bitwarden.desktop"
    "com.github.PintaProject.Pinta"
    "com.github.tchx84.Flatseal"
    "com.google.Chrome"
    "com.mattjakeman.ExtensionManager"
    "com.obsproject.Studio"
    "com.ranfdev.DistroShelf"
    "dev.zed.Zed"
    "io.github.flattool.Ignition"
    "io.github.flattool.Warehouse"
    "io.github.kolunmi.Bazaar"
    "io.gitlab.adhami3310.Impression"
    "it.mijorus.smile"
    "org.gtk.Gtk3theme.adw-gtk3"
    "org.gtk.Gtk3theme.adw-gtk3-dark"
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
      gnome-tour
      epiphany # Substituído pelo Google Chrome (Flatpak)
      gnome-console # Substituído pelo Ptyxis (Nix)
      gnome-terminal # Terminal legado — usar Ptyxis (Nix)
      gnome-music
      gnome-software # Substituído pelo Bazaar (Flatpak)
    ];

    systemPackages = with pkgs; [
      ptyxis # Terminal moderno para GNOME
      gjs # Motor JavaScript para GNOME (GObject Introspection)
    ];
  };

  programs.dconf = {
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
