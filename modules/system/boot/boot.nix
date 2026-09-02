# Boot module: systemd-boot + Plymouth for a flicker-free experience
{ lib, pkgs, ... }:

{
  boot = {
    # Latest Linux kernel (non-LTS)
    kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;
    # systemd-boot as the default boot manager
    # Note: barbudus and bigodon override this with boot.loader.limine (see hosts/<host>/configuration.nix)
    loader = {
      systemd-boot = {
        enable = lib.mkDefault true;
        configurationLimit = 10;
        editor = false; # Disable the boot editor (security)
        # Keep max resolution in the boot menu, avoiding flickering
        consoleMode = lib.mkDefault "max";
      };
      efi.canTouchEfiVariables = true;
      # timeout = 0: hides the menu and boots the default entry immediately,
      # avoiding the flicker caused by displaying the menu during boot.
      # To show the menu manually, hold down the Space key (or any key)
      # right after the UEFI firmware screen, during the boot window.
      # To change it temporarily via terminal: sudo bootctl set-timeout <seconds>
      # Note: Limine hosts override this with timeout = 1 — Limine requires a
      # non-zero value to accept keyboard input at all (unlike systemd-boot,
      # which silently polls for keys even with timeout = 0).
      timeout = lib.mkDefault 0;
    };

    # Plymouth for the boot splash screen
    plymouth = {
      enable = true;
      # bgrt: uses the firmware's OEM logo (ACPI BGRT) for a smooth
      # firmware → bootloader → Plymouth transition without flickering
      theme = lib.mkDefault "bgrt";
    };

    # Kernel parameters for a quiet/flicker-free boot
    kernelParams = [
      "quiet"
      "splash"
      "loglevel=3"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
      # Disable boot messages on the framebuffer
      "vt.global_cursor_default=0"
    ];

    # Suppress kernel messages on the console during boot
    consoleLogLevel = 0;

    # Quiet initrd
    initrd.verbose = false;
  };

  # Framebuffer configuration to avoid flickering
  # (KMS/DRM keeps the boot resolution when loading the driver)
  # Host-specific KMS modules (i915, nvidia, etc.) are defined per host
  # via boot.initrd.kernelModules in hardware-configuration.nix
}
