# Módulo base do ambiente gráfico — partilhado por todos os desktops.
# A configuração específica do GNOME vive em dendritic/flake/gnome-wrapper.nix.
{ pkgs, ... }:
{
  programs = {
    # Habilita execução de binários FHS não-patchados (ex.: dev tools distribuídos
    # como binários genéricos Linux). Sem nix-ld, eles falham com "stub-ld" errors.
    nix-ld = {
      enable = true;
      libraries = with pkgs; [
        stdenv.cc.cc.lib # libstdc++.so.6
        zlib
        alsa-lib # libasound.so.2
        wayland # libwayland-client.so.0
      ];
    };
  };

  # XDG Portal para integração com GNOME (apps Nix e Flatpak)
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-gnome
    ];
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

  # Editores gráficos com ambiente FHS: permitem que extensões e ferramentas
  # auxiliares que dependem de paths FHS padrão funcionem corretamente no NixOS.
  environment.systemPackages = with pkgs; [
    vscode-fhs
    zed-editor-fhs
  ];

  # Electron: forçar detecção automática de Wayland em todos os apps Nix.
  environment.variables.ELECTRON_OZONE_PLATFORM_HINT = "auto";
}
