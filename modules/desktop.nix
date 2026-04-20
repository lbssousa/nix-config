# Módulo de ambiente gráfico: GNOME + Flatpak
# Experiência similar ao Fedora Silverblue / Bluefin
{ pkgs, lib, ... }:

let
  # Flatpaks padrão do sistema (baseado no projeto Bluefin)
  # Ref: https://github.com/projectbluefin/common/blob/main/system_files/bluefin/usr/share/ublue-os/homebrew/system-flatpaks.Brewfile
  # Firefox e Thunderbird excluídos intencionalmente
  systemFlatpaks = [
    "com.brave.Browser"
    "com.github.PintaProject.Pinta"
    "com.github.tchx84.Flatseal"
    "com.mattjakeman.ExtensionManager"
    "com.ranfdev.DistroShelf"
    "io.github.flattool.Ignition"
    "io.github.flattool.Warehouse"
    "io.github.kolunmi.Bazaar"
    "io.gitlab.adhami3310.Impression"
    "io.missioncenter.MissionCenter"
    "it.mijorus.smile"
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
    "org.gtk.Gtk3theme.adw-gtk3"
    "org.gtk.Gtk3theme.adw-gtk3-dark"
    "page.tesk.Refine"
  ];
  # Hash (8 hex chars) da lista para detectar mudanças e reexecutar a instalação
  flatpaksListHash = builtins.substring 0 8 (
    builtins.hashString "sha256" (lib.concatStringsSep "\n" systemFlatpaks)
  );
  flatpakDoneFile = "/var/lib/nixos-flatpak-setup/done-${flatpaksListHash}";
in
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
    epiphany # Browser padrão do GNOME - usar Brave (Flatpak)
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

  # Brave browser instalado via Flatpak (ver serviço install-system-flatpaks)
  # Definir Brave como browser padrão via xdg-mime
  xdg.mime.defaultApplications = {
    "text/html" = "com.brave.Browser.desktop";
    "x-scheme-handler/http" = "com.brave.Browser.desktop";
    "x-scheme-handler/https" = "com.brave.Browser.desktop";
    "x-scheme-handler/about" = "com.brave.Browser.desktop";
    "x-scheme-handler/unknown" = "com.brave.Browser.desktop";
  };

  # Instalar Flatpaks padrão automaticamente via Flathub na primeira inicialização
  # O serviço reexecuta apenas quando a lista de Flatpaks muda (baseado no hash da lista)
  systemd.services.install-system-flatpaks = {
    description = "Instalar Flatpaks padrão do sistema";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network-online.target"
      "flatpak-system-helper.service"
    ];
    wants = [ "network-online.target" ];
    unitConfig.ConditionPathExists = "!${flatpakDoneFile}";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      StateDirectory = "nixos-flatpak-setup";
    };
    script = ''
      # Adicionar repositório Flathub se não existir
      ${pkgs.flatpak}/bin/flatpak remote-add --system --if-not-exists flathub \
        https://dl.flathub.org/repo/flathub.flatpakrepo
      # Instalar Flatpaks do sistema (falhas individuais são registradas mas não interrompem)
      for pkg in ${lib.escapeShellArgs systemFlatpaks}; do
        if ! ${pkgs.flatpak}/bin/flatpak install --system --noninteractive flathub "$pkg"; then
          echo "AVISO: Falha ao instalar $pkg" >&2
        fi
      done
      touch ${lib.escapeShellArg flatpakDoneFile}
    '';
  };

  # Fontes essenciais para o desktop
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
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
