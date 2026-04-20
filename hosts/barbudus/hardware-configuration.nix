# Hardware configuration para barbudus (Dell Inspiron 14 5490)
# NOTA: Este arquivo deve ser regenerado com: nixos-generate-config --no-filesystems --root /mnt
# após a instalação do disko. O arquivo gerado deve substituir este template.
{ lib, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    # Configuração de disco via disko
    ./disko.nix
  ];

  # Módulos do kernel para Intel + NVME + USB
  boot = {
    initrd = {
      availableKernelModules =
        [ "xhci_pci" "ahci" "nvme" "usb_storage" "sd_mod" "rtsx_pci_sdmmc" ];
      kernelModules = [
        "dm-snapshot"
        # Intel KMS para boot flicker-free
        "i915"
      ];
    };
    kernelModules = [ "kvm-intel" "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];
    extraModulePackages = [ ];
  };

  # ID único do host para ZFS (gerado com: head -c 8 /dev/urandom | od -A n -t x1 | tr -d ' \n')
  networking.hostId = "a8b3c4d5"; # ALTERE para um valor único gerado no seu sistema

  # Microcode Intel
  hardware.cpu.intel.updateMicrocode = true;

  # Filesystems configurados via disko.nix
  # Deixar vazio para o disko configurar
  swapDevices = lib.mkForce [ ];

  # Marcar /persist como necessário no boot (impermanence)
  fileSystems."/persist".neededForBoot = true;

  # Swap híbrida: 20 GB em disco (hibernação) + 8 GB zram (performance)
  zramSwap = {
    enable = true;
    # 8 GB de zram (50% da RAM física de 16 GB)
    # Com compressão zstd 2:1 a 3:1, oferece ~12-16 GB efetivos
    memoryPercent = 50;
    algorithm = "zstd";
    priority = 100; # Prioridade maior que swap em disco
  };

  # Otimizações de kernel para swap híbrida
  boot.kernel.sysctl = {
    "vm.swappiness" = 10; # Tendência menor de usar swap (bom para laptops)
    "vm.vfs_cache_pressure" = 50; # Manter páginas em cache
    "vm.dirty_ratio" = 10;
    "vm.dirty_background_ratio" = 5;
  };

  # Networking
  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.enableRedistributableFirmware = true;
}
