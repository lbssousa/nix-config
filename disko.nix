# Template base de particionamento para Btrfs com LUKS + LVM
# A raiz (/) usa tmpfs (sempre limpa a cada boot — sem necessidade de snapshot/rollback)
# Os demais filesystems usam subvolumes Btrfs (dados persistentes)
# Utilizado pelos hosts via: import ../../disko.nix { inherit lib; device = "..."; swapSize = "..."; }
{
  device ? throw "Defina o dispositivo de disco, ex: /dev/nvme0n1",
  swapSize ? "20G",
  lib,
  ...
}:
let
  hasSwap = swapSize != "0" && swapSize != "";
in
{
  disko.devices = {
    # Raiz efêmera: tmpfs — limpa automaticamente a cada boot, sem rollback necessário
    # O preservation preserva arquivos importantes via bind mounts de /persist
    nodev."/" = {
      fsType = "tmpfs";
      mountOptions = [
        "defaults"
        "size=50%" # 50% da RAM; ajuste conforme necessário
        "mode=755"
      ];
    };

    disk.main = {
      inherit device;
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          # Partição EFI para systemd-boot
          esp = {
            name = "ESP";
            size = "512M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [
                "fmask=0077"
                "dmask=0077"
              ];
            };
          };
          # Partição principal criptografada com LUKS
          luks = {
            name = "luks";
            size = "100%";
            content = {
              type = "luks";
              name = "crypted";
              settings = {
                allowDiscards = true;
              };
              # Dentro do LUKS, usa LVM para swap + volume Btrfs
              content = {
                type = "lvm_pv";
                vg = "root_vg";
              };
            };
          };
        };
      };
    };

    # Grupo de volumes LVM dentro do LUKS
    lvm_vg.root_vg = {
      type = "lvm_vg";
      lvs = lib.mkMerge [
        # Swap em disco (somente se swapSize != "0")
        (lib.mkIf hasSwap {
          swap = {
            size = swapSize;
            content = {
              type = "swap";
              resumeDevice = true; # Suporte a hibernação
            };
          };
        })
        # Volume lógico para o sistema de arquivos Btrfs
        {
          root = {
            size = "100%FREE";
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ]; # Forçar criação (sobrescreve fs existente se necessário)

              subvolumes = {
                # Nix store — preservado (essencial para o sistema funcionar)
                "@nix" = {
                  mountpoint = "/nix";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };

                # Dados persistentes do sistema — usados pelo módulo preservation
                "@persist" = {
                  mountpoint = "/persist";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };

                # Logs do sistema — sem compressão (logs já são comprimidos internamente)
                "@log" = {
                  mountpoint = "/var/log";
                  mountOptions = [ "noatime" ];
                };

                # Dados de containers (Podman, Docker, etc.) — preservados
                "@containers" = {
                  mountpoint = "/var/lib/containers";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };

                # Aplicações Flatpak — preservadas entre boots
                "@flatpak" = {
                  mountpoint = "/var/lib/flatpak";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };

                # Snapshots Btrfs — para backups futuros (snapper, timeshift, etc.)
                "@snapshots" = {
                  mountpoint = "/.snapshots";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
              };
            };
          };
        }
      ];
    };
  };
}
