# Módulo de ambiente gráfico: GNOME + Flatpak
# Experiência similar ao Fedora Silverblue / Bluefin
{ pkgs, lib, ... }:

let
  # Flatpaks padrão do sistema (baseado no projeto Bluefin)
  # Ref: https://github.com/projectbluefin/common/blob/main/system_files/bluefin/usr/share/ublue-os/homebrew/system-flatpaks.Brewfile
  # Firefox e Thunderbird excluídos intencionalmente
  systemFlatpaks = [
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
  # Hash (8 hex chars, suficiente para detectar mudanças na lista) para reexecutar a instalação
  flatpaksListHash = builtins.substring 0 8 (
    builtins.hashString "sha256" (lib.concatStringsSep "\n" systemFlatpaks)
  );
  flatpakDoneFile = "/var/lib/nixos-flatpak-setup/done-${flatpaksListHash}";
in
{
  services = {
    # Display Manager e Desktop Environment (Wayland)
    displayManager.gdm = {
      enable = true;
      wayland = true; # Preferir sessão Wayland
    };

    desktopManager.gnome.enable = true;

    # Flatpak - instalação system-wide
    flatpak.enable = true;

    # Bluetooth
    blueman.enable = true;

    # Impressão (CUPS)
    printing.enable = true;
  };

  # Excluir pacotes padrão do GNOME que serão substituídos por Nix ou Flatpaks
  environment.gnome.excludePackages = with pkgs; [
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

  # Brave e Ptyxis instalados via Nix
  environment.systemPackages = with pkgs; [
    brave # Navegador padrão
    ptyxis # Terminal moderno (substitui GNOME Console)
  ];

  # Brave browser instalado via Nix
  # Definir Brave como browser padrão via xdg-mime
  xdg.mime.defaultApplications = {
    "text/html" = "brave-browser.desktop";
    "x-scheme-handler/http" = "brave-browser.desktop";
    "x-scheme-handler/https" = "brave-browser.desktop";
    "x-scheme-handler/about" = "brave-browser.desktop";
    "x-scheme-handler/unknown" = "brave-browser.desktop";
  };

  # Instalar Flatpaks padrão automaticamente via Flathub na primeira inicialização
  # O serviço reexecuta apenas quando a lista de Flatpaks muda (baseado no hash da lista)
  systemd.services.install-system-flatpaks = {
    description = "Instalar Flatpaks padrão do sistema";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
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
    ''
    + lib.concatMapStrings (pkg: ''
      if ! ${pkgs.flatpak}/bin/flatpak info --system ${lib.escapeShellArg pkg} \
          >/dev/null 2>&1; then
        if ! ${pkgs.flatpak}/bin/flatpak install --system --noninteractive flathub ${lib.escapeShellArg pkg}; then
          echo "AVISO: Falha ao instalar ${lib.escapeShellArg pkg}" >&2
        fi
      fi
    '') systemFlatpaks
    + ''
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
