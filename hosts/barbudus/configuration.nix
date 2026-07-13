# Main configuration for barbudus (Dell Inspiron 14 5490)
# Hardware: Intel i5-10210U, 16 GB RAM, Intel UHD 620 + NVIDIA GeForce MX230
{
  config,
  lib,
  pkgs,
  ...
}:
{
  # Host name
  networking.hostName = "barbudus";

  # --- NVIDIA drivers (proprietary) ---
  # GeForce MX230 with PRIME offload (integrated Intel + discrete NVIDIA)
  #
  # HOW TO USE THE DEDICATED GPU:
  # - Terminal: nvidia-offload <app>  (e.g. nvidia-offload blender)
  # - Helper: run-with-nvidia <app>   (alias with better UX)
  # - Check: glxinfo | grep "NVIDIA" or nvidia-smi

  # Enable OpenGL/Vulkan and VA-API support
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-media-driver # iHD driver for Intel UHD 620 (Comet Lake)
      intel-vaapi-driver # i965 driver (fallback for legacy content)
      nvidia-vaapi-driver # VA-API via NVDEC for GeForce MX230
    ];
  };

  # Force iHD as the default VA-API driver (avoids i965 being picked
  # automatically, which would limit the supported formats)
  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";

  # "nvidia" must be listed here even in PRIME offload mode: nixpkgs'
  # hardware/video/nvidia.nix module gates the whole proprietary driver
  # build (boot.extraModulePackages, kernel module, offload udev rules)
  # behind `elem "nvidia" videoDrivers`. Without it, hardware.nvidia.*
  # below is silently a no-op — the kernel module never gets built, even
  # though boot.kernelModules in hardware-configuration.nix still lists
  # nvidia/nvidia_drm/nvidia_modeset/nvidia_uvm as modules to load.
  # "modesetting" stays first so the Intel iGPU remains the primary X driver.
  services.xserver.videoDrivers = [
    "modesetting"
    "nvidia"
  ];

  # NVIDIA proprietary driver
  hardware.nvidia = {
    # Force version 580.x (stable = 595.x is incompatible with GeForce MX230)
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
    modesetting.enable = true;
    open = false; # MX230 is an old GPU, use the proprietary driver (not open-source)
    powerManagement = {
      enable = true;
      finegrained = true; # Power off the NVIDIA GPU when unused (battery savings)
    };
    prime = {
      # PCI bus IDs (check with: lspci | grep -E "VGA|3D")
      # Example: 00:02.0 = Intel, 01:00.0 = NVIDIA
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
      # PRIME offload: uses Intel by default, NVIDIA on demand
      offload = {
        enable = true;
        enableOffloadCmd = true; # Enables the 'nvidia-offload' command
      };
    };
  };

  # --- Fingerprint (Goodix 538d sensor, USB 27c6:538d) ---
  # fprintd-goodix = fprintd 1.94.5 + libfprint from the lbssousa fork (1.94.10).
  # See pkgs/libfprint-goodix and pkgs/fprintd-goodix.
  services = {

    # switcheroo-control: exposes GPUs via D-Bus (for GNOME and other tools)
    switcherooControl.enable = true;

    fprintd = {
      enable = true;
      package = pkgs.fprintd-goodix;
    };

    # --- Power settings for laptop ---
    power-profiles-daemon.enable = true;
    thermald.enable = true; # Intel thermal management
  };

  # --- Bootloader: Limine with Secure Boot ---
  # PKI keys managed via sbctl, stored in /persist/etc/secureboot.
  # NOTE: Requires initial key setup (see INSTALLATION.md)
  boot.loader.systemd-boot.enable = lib.mkForce false; # Replaced by Limine
  boot.loader.limine = {
    enable = true;
    maxGenerations = 10; # equivalent to systemd-boot's configurationLimit in boot.nix
    secureBoot.enable = true;
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

  environment.systemPackages = [
    # sbctl is required to manage Secure Boot keys and for manual
    # inspection (sbctl status/verify).
    pkgs.sbctl

    # Helper script to run applications with nvidia-offload
    (pkgs.writeScriptBin "run-with-nvidia" ''
      #!/usr/bin/env bash
      # Helper to run applications with the dedicated NVIDIA GPU
      # Usage: run-with-nvidia <command> [args...]
      if [[ -z "$1" ]]; then
        echo "Usage: run-with-nvidia <command> [args...]"
        echo "Example: run-with-nvidia glxinfo"
        echo "         run-with-nvidia blender"
        exit 1
      fi
      nvidia-offload "$@"
    '')
  ];

  # Create a /var/lib/sbctl → /persist/etc/secureboot symlink on every boot.
  # Needed because the root (/) is tmpfs and gets wiped on every reboot.
  # The boot.loader.limine module does not create this symlink
  # automatically; it's the host config's responsibility to create it via
  # systemd-tmpfiles. Without it, sbctl can't find the PKI key store.
  systemd.tmpfiles.rules = [
    "L+ /var/lib/sbctl - - - - /persist/etc/secureboot"
  ];
}
