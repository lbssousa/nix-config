# Módulo de ambiente gráfico: GNOME + Flatpak + Brave
# Experiência similar ao Fedora Silverblue / Bluefin
{ pkgs, ... }:

{
  services = {
    # Servidor X11 básico (necessário mesmo com Wayland)
    xserver = {
      enable = true;
      # Driver de vídeo definido por cada host
      displayManager.gdm = {
        enable = true;
        wayland = true; # Preferir sessão Wayland
      };
      desktopManager.gnome.enable = true;
    };

    # Flatpak - instalação system-wide
    flatpak.enable = true;

    # Bluetooth
    blueman.enable = true;

    # Impressão (CUPS)
    printing.enable = true;
  };

  # Excluir pacotes padrão do GNOME que serão substituídos por Flatpaks
  environment.gnome.excludePackages = with pkgs; [
    gnome-software # Substituído pelo Bazaar (Flatpak)
    gnome-tour
    epiphany # Browser padrão do GNOME - usar Brave
    evince # PDF viewer - usar Papers (Flatpak)
    gnome-terminal # Terminal - usar Ptyxis (Flatpak)
    totem # Player de vídeo
    cheese # Webcam app
    gnome-music
    gnome-maps
    gnome-weather
    gnome-contacts
    gnome-calendar
    gnome-clocks
  ];

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

  # Brave browser - instalado via Nix para todos os usuários
  # Definido como browser padrão do sistema
  environment.systemPackages = with pkgs; [ brave ];

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
      noto-fonts-emoji
      liberation_ttf
      nerd-fonts.fira-code
      nerd-fonts.jetbrains-mono
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
