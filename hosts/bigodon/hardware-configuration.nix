# Hardware configuration para bigodon (Morefine M6 Mini-PC)
# NOTA: Este arquivo deve ser regenerado com: nixos-generate-config --no-filesystems --root /mnt
# após a instalação do disko. O arquivo gerado deve substituir este template.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    # Configuração de disco via disko
    ./disko.nix
  ];

  # Módulos do kernel para Intel N200 + NVME + USB
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "nvme"
    "usb_storage"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [
    "dm-snapshot"
    # Intel KMS para boot flicker-free
    "i915"
  ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [];

  # ID único do host para ZFS (gerado com: head -c 8 /dev/urandom | od -A n -t x1 | tr -d ' \n')
  networking.hostId = "b9c4d5e6"; # ALTERE para um valor único gerado no seu sistema

  # Microcode Intel
  hardware.cpu.intel.updateMicrocode = true;

  # Filesystems configurados via disko.nix
  swapDevices = lib.mkForce [];

  # Marcar /persist como necessário no boot (impermanence)
  fileSystems."/persist".neededForBoot = true;

  # Swap híbrida: 20 GB em disco (hibernação) + 8 GB zram (performance)
  zramSwap = {
    enable = true;
    memoryPercent = 50;
    algorithm = "zstd";
    priority = 100;
  };

  # Otimizações de kernel para swap híbrida
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
