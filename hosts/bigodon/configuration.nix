# Main configuration for bigodon (Morefine M6 Mini-PC)
# Hardware: Intel N200, 16 GB RAM, Intel UHD Graphics (integrated)
{ lib, pkgs, ... }:

{
  # Host name
  networking.hostName = "bigodon";

  # --- Bootloader: Limine (no Secure Boot) ---
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.limine = {
    enable = true;
    maxGenerations = 10; # equivalent to systemd-boot's configurationLimit in boot.nix
    # boot.loader.timeout = 0 (set in modules/system/boot/boot.nix) already makes
    # Limine skip the menu and boot the default entry immediately. Limine still
    # renders one frame before honoring that timeout though, and by default
    # (upstream mkDefault) that frame shows the NixOS dark-gray bootloader
    # artwork. Disable that wallpaper and use a plain black backdrop instead,
    # matching Plymouth's bgrt background, so the frame is imperceptible.
    style = {
      wallpapers = [ ];
      backdrop = "000000";
      interface.helpHidden = true;
    };
  };

  # --- Intel UHD Graphics (integrated in the N200) ---
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    # VA-API for video acceleration
    extraPackages = with pkgs; [
      intel-media-driver # iHD driver (N200 uses Jasper Lake)
      intel-vaapi-driver # i965 driver (fallback)
      libvdpau-va-gl # VDPAU via VA-API
    ];
  };

  # Intel UHD Graphics uses modesetting natively on Wayland

  # Power settings for mini-PC
  services.power-profiles-daemon.enable = true;
}
