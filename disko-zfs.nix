# Template de particionamento ZFS com LUKS
# A raiz (/) usa um dataset ZFS revertido ao snapshot @blank a cada boot
# (impermanência sem tmpfs — permite rollback e snapshots nativos do ZFS)
# Os demais filesystems usam datasets ZFS persistentes
# Utilizado pelos hosts via: import ../../disko-zfs.nix { inherit lib; device = "..."; swapSize = "..."; }
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
    disk.main = {
      inherit device;
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          # Partição EFI para systemd-boot / Limine
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
          # Partição principal criptografada com LUKS, contendo o pool ZFS
          luks = {
            name = "luks";
            size = "100%";
            content = {
              type = "luks";
              name = "crypted";
              settings = {
                allowDiscards = true;
              };
              # Dentro do LUKS, o pool ZFS é criado diretamente no dispositivo
              content = {
                type = "zfs";
                pool = "zroot";
              };
            };
          };
        };
      };
    };

    # Pool ZFS principal
    zpool.zroot = {
      type = "zpool";
      options = {
        ashift = "12"; # Otimizado para discos com setor de 4K (NVMe, SSDs modernos)
        autotrim = "on"; # TRIM automático para SSDs/NVMe
      };
      rootFsOptions = {
        compression = "zstd"; # Compressão eficiente para dados gerais
        "com.sun:auto-snapshot" = "false"; # Desabilitar auto-snapshot (gerenciado manualmente)
        mountpoint = "none"; # Não montar o pool raiz diretamente
        xattr = "sa"; # Atributos estendidos como atributos de sistema (mais eficiente)
        acltype = "posixacl"; # ACLs POSIX (necessário para aplicações modernas)
        dnodesize = "auto"; # Tamanho do dnode adaptável (melhora compatibilidade)
      };

      datasets = lib.mkMerge [
        # Swap em ZVOL (somente se swapSize != "0")
        # NOTA: ZVOL swap não suporta hibernação (suspend-to-disk).
        # Para hibernação, use o perfil Btrfs (com swap em LVM+LUKS e resumeDevice=true).
        (lib.mkIf hasSwap {
          swap = {
            type = "zfs_volume";
            size = swapSize;
            content = {
              type = "swap";
            };
            options = {
              volblocksize = "4096";
              compression = "lz4"; # Compressão leve para swap (melhor ratio que zle)
              "com.sun:auto-snapshot" = "false";
            };
          };
        })
        {
          # ── Datasets locais (sem backup necessário — recriáveis) ──────────

          # Contêiner para datasets locais
          "local" = {
            type = "zfs_fs";
            options.mountpoint = "none";
          };

          # Raiz efêmera — revertida ao snapshot @blank a cada boot pelo initrd
          # O módulo preservation-zfs.nix configura o rollback automático via
          # boot.initrd.postDeviceCommands (initrd legado) ou systemd initrd service.
          "local/root" = {
            type = "zfs_fs";
            mountpoint = "/";
            options = {
              mountpoint = "legacy";
              "com.sun:auto-snapshot" = "false";
            };
            # Snapshot blank criado logo após a formatação; usado para rollback no boot
            postCreateHook = "zfs snapshot zroot/local/root@blank";
          };

          # Nix store — preservado (essencial para o sistema funcionar), sem backup
          "local/nix" = {
            type = "zfs_fs";
            mountpoint = "/nix";
            options = {
              mountpoint = "legacy";
              "com.sun:auto-snapshot" = "false";
              atime = "off"; # Desabilitar atime para melhor performance no /nix
            };
          };

          # ── Datasets seguros (dados persistentes — backup recomendado) ────

          # Contêiner para datasets persistentes
          "safe" = {
            type = "zfs_fs";
            options.mountpoint = "none";
          };

          # Diretórios de usuário — preservados entre boots
          "safe/home" = {
            type = "zfs_fs";
            mountpoint = "/home";
            options.mountpoint = "legacy";
          };

          # Dados persistentes do sistema — usados pelo módulo preservation
          "safe/persist" = {
            type = "zfs_fs";
            mountpoint = "/persist";
            options.mountpoint = "legacy";
          };

          # Logs do sistema
          "safe/log" = {
            type = "zfs_fs";
            mountpoint = "/var/log";
            options = {
              mountpoint = "legacy";
              compression = "lz4"; # lz4 é eficiente para logs de texto com baixo overhead
            };
          };

          # Dados de containers (Podman, Docker, etc.) — preservados
          "safe/containers" = {
            type = "zfs_fs";
            mountpoint = "/var/lib/containers";
            options.mountpoint = "legacy";
          };

          # Aplicações Flatpak — preservadas entre boots
          "safe/flatpak" = {
            type = "zfs_fs";
            mountpoint = "/var/lib/flatpak";
            options.mountpoint = "legacy";
          };
        }
      ];
    };
  };
}
