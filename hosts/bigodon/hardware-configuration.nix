# Hardware configuration for bigodon (Morefine M6 Mini-PC)
# NOTE: This file should be regenerated with: nixos-generate-config --no-filesystems --root /mnt
# after the disko install. The generated file should replace this template.
{ lib, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    # Disk configuration via disko
    ./disko.nix
  ];

  # Kernel modules for Intel N200 + NVME + USB
  boot = {
    initrd = {
      availableKernelModules = [
        "xhci_pci"
        "ahci"
        "nvme"
        "usb_storage"
        "sd_mod"
      ];
      kernelModules = [
        "dm-snapshot"
        # Intel KMS for flicker-free boot
        "i915"
      ];
    };
    kernelModules = [ "kvm-intel" ];
    extraModulePackages = [ ];
  };

  # Intel microcode
  hardware.cpu.intel.updateMicrocode = true;

  # Filesystems configured via disko.nix
  swapDevices = lib.mkForce [ ];

  # Mark /persist as needed for boot (preservation)
  fileSystems."/persist".neededForBoot = true;

  # Hybrid swap: 20 GB on disk (hibernation) + 8 GB zram (performance)
  zramSwap = {
    enable = true;
    memoryPercent = 50;
    algorithm = "zstd";
    priority = 100;
  };

  # Kernel tuning for hybrid swap
  boot.kernel.sysctl = {
    "vm.swappiness" = 10;
    "vm.vfs_cache_pressure" = 50;
    "vm.dirty_ratio" = 10;
    "vm.dirty_background_ratio" = 5;
  };

  # Networking
  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.enableRedistributableFirmware = true;
}
