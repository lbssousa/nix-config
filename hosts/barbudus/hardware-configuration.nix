# Hardware configuration for barbudus (Dell Inspiron 14 5490)
# NOTE: This file should be regenerated with: nixos-generate-config --no-filesystems --root /mnt
# after the disko install. The generated file should replace this template.
{ lib, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    # Disk configuration via disko
    ./disko.nix
  ];

  # Kernel modules for Intel + NVME + USB
  boot = {
    initrd = {
      availableKernelModules = [
        "xhci_pci"
        "ahci"
        "nvme"
        "usb_storage"
        "sd_mod"
        "rtsx_pci_sdmmc"
      ];
      kernelModules = [
        "dm-snapshot"
        # Intel KMS for flicker-free boot
        "i915"
      ];
    };
    kernelModules = [
      "kvm-intel"
      "nvidia"
      "nvidia_modeset"
      "nvidia_uvm"
      "nvidia_drm"
    ];
    extraModulePackages = [ ];
  };

  # Intel microcode
  hardware.cpu.intel.updateMicrocode = true;

  # Filesystems configured via disko.nix
  # Leave empty for disko to configure
  swapDevices = lib.mkForce [ ];

  # Mark /persist as needed for boot (preservation)
  fileSystems."/persist".neededForBoot = true;

  # Hybrid swap: 20 GB on disk (hibernation) + 8 GB zram (performance)
  zramSwap = {
    enable = true;
    # 8 GB of zram (50% of the 16 GB physical RAM)
    # With zstd compression at 2:1 to 3:1, gives ~12-16 GB effective
    memoryPercent = 50;
    algorithm = "zstd";
    priority = 100; # Higher priority than disk swap
  };

  # Kernel tuning for hybrid swap
  boot.kernel.sysctl = {
    "vm.swappiness" = 10; # Lower tendency to use swap (good for laptops)
    "vm.vfs_cache_pressure" = 50; # Keep pages in cache
    "vm.dirty_ratio" = 10;
    "vm.dirty_background_ratio" = 5;
  };

  # Networking
  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.enableRedistributableFirmware = true;
}
