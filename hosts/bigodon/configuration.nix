# Configuração principal para bigodon (Morefine M6 Mini-PC)
# Hardware: Intel N200, 16 GB RAM, Intel UHD Graphics (integrada)
{ pkgs, ... }:

{
  imports = [
    ../../modules/system/core/common.nix
    ../../modules/system/core/impermanence.nix
    ../../modules/system/audio/audio.nix
    ../../modules/system/boot/boot.nix
    ../../modules/system/containers/containers.nix
    ../../modules/system/desktop/desktop.nix
    ../../modules/system/hardware/printing.nix
    ../../modules/system/network/ssh.nix
    ../../modules/system/network/wifi.nix
    ../../modules/system/security/tpm2.nix
    ../../modules/system/shell/shells.nix
    ../../modules/system/tools/homebrew.nix
    ../../modules/system/tools/lbnix.nix
    ../../modules/system/tools/packages.nix
    ../../modules/system/users/users.nix
    # Configurações de usuário
    ./../../users/abutre.nix
    ./../../users/roberta.nix
    ./../../users/miguel.nix
    ./../../users/jose.nix
    ./../../users/joao.nix
    ./../../users/maria.nix
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
