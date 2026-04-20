# Template base de particionamento para ZFS com LUKS + LVM
# Utilizado pelos hosts via: import ../../disko.nix { inherit lib; device = "..."; swapSize = "..."; }
{
  device ? throw "Defina o dispositivo de disco, ex: /dev/nvme0n1",
  swapSize ? "20G",
  poolName ? "rpool",
  lib,
  ...
}:
let
  hasSwap = swapSize != "0" && swapSize != "";
in
{
  disko.devices = {
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
              # Dentro do LUKS, usa LVM para swap + pool ZFS
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
        # Volume lógico para o pool ZFS
        {
          zpool = {
            size = "100%FREE";
            content = {
              type = "zfs";
              pool = poolName;
            };
          };
        }
      ];
    };

    # Pool ZFS com datasets organizados em local (reconstruível) e safe (preservado)
    zpool.${poolName} = {
      type = "zpool";
      rootFsOptions = {
        compression = "zstd";
        atime = "off";
        xattr = "sa";
        dnodesize = "auto";
        normalization = "formD";
        "com.sun:auto-snapshot" = "false";
      };
      options = {
        ashift = "12";
        autotrim = "on";
      };

      datasets = {
        # --- Datasets locais (podem ser reconstruídos) ---

        "local" = {
          type = "zfs_fs";
          options.mountpoint = "none";
        };

        # Raiz efêmera - limpa a cada boot via rollback para @blank snapshot
        "local/root" = {
          type = "zfs_fs";
          mountpoint = "/";
          options.mountpoint = "legacy";
          # Cria snapshot vazio imediatamente após a criação do dataset
          postCreateHook = "zfs snapshot ${poolName}/local/root@blank";
        };

        # Nix store - preservado (essencial para o sistema funcionar)
        "local/nix" = {
          type = "zfs_fs";
          mountpoint = "/nix";
          options.mountpoint = "legacy";
        };

        # Logs do sistema - preservados, compressão desabilitada (logs já são comprimidos)
        "local/log" = {
          type = "zfs_fs";
          mountpoint = "/var/log";
          options = {
            mountpoint = "legacy";
            compression = "off";
          };
        };

        # Dados de containers (Podman, Docker, etc.) - preservados
        "local/containers" = {
          type = "zfs_fs";
          mountpoint = "/var/lib/containers";
          options.mountpoint = "legacy";
        };

        # --- Datasets seguros (devem ser preservados/backupeados) ---

        "safe" = {
          type = "zfs_fs";
          options = {
            mountpoint = "none";
            "com.sun:auto-snapshot" = "true";
          };
        };

        # Diretórios de usuário - preservados entre boots
        "safe/home" = {
          type = "zfs_fs";
          mountpoint = "/home";
          options.mountpoint = "legacy";
        };

        # Dados persistentes do sistema - usados pelo módulo impermanence
        "safe/persist" = {
          type = "zfs_fs";
          mountpoint = "/persist";
          options.mountpoint = "legacy";
        };

        # Aplicações Flatpak - preservadas entre boots
        "safe/flatpak" = {
          type = "zfs_fs";
          mountpoint = "/var/lib/flatpak";
          options.mountpoint = "legacy";
        };
      };
    };
  };
}
