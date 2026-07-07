# Configuração principal para bigodon (Morefine M6 Mini-PC)
# Hardware: Intel N200, 16 GB RAM, Intel UHD Graphics (integrada)
{ lib, pkgs, ... }:

{
  # Nome do host
  networking.hostName = "bigodon";

  # --- Bootloader: Limine (piloto para futura migração do Secure Boot em barbudus) ---
  # bigodon não usa Secure Boot, o que o torna o host de menor risco para validar
  # o módulo boot.loader.limine antes de aplicá-lo em barbudus (lanzaboote + NVIDIA + TPM2).
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.limine = {
    enable = true;
    maxGenerations = 10; # equivalente ao configurationLimit do systemd-boot em boot.nix
  };

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

  # Intel UHD Graphics usa modesetting nativamente em Wayland

  # Configurações de energia para mini-PC
  services.power-profiles-daemon.enable = true;
}
