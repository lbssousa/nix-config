# Configuração principal para bigodon (Morefine M6 Mini-PC)
# Hardware: Intel N200, 16 GB RAM, Intel UHD Graphics (integrada)
{ pkgs, ... }:

{
  imports = [
    ../../modules/common.nix
    ../../modules/audio.nix
    ../../modules/boot.nix
    ../../modules/containers.nix
    ../../modules/desktop.nix
    ../../modules/homebrew.nix
    ../../modules/impermanence.nix
    ../../modules/packages.nix
    ../../modules/printing.nix
    ../../modules/shells.nix
    ../../modules/ssh.nix
    ../../modules/tpm2.nix
    ../../modules/users.nix
    # Carregar configurações de usuário (não commitadas - ver .gitignore)
    # Descomente e ajuste conforme necessário:
    # ./../../users/seu-usuario.nix
  ];

  # Nome do host
  networking.hostName = "bigodon";

  # --- Intel UHD Graphics (integrada no N200) ---
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    # VA-API para aceleração de vídeo
    extraPackages = with pkgs; [
      intel-media-driver # iHD driver (N200 usa Jasper Lake)
      intel-vaapi-driver # i965 driver (fallback)
      libvdpau-va-gl # VDPAU via VA-API
    ];
  };

  # Driver Intel modesetting (KMS/Wayland)
  services.xserver.videoDrivers = [ "modesetting" ];

  # Configurações de energia para mini-PC
  services.power-profiles-daemon.enable = true;
}
