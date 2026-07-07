# ZFS partitioning template with LUKS
# The root (/) uses a ZFS dataset reverted to the @blank snapshot on every boot
# (impermanence without tmpfs — enables native ZFS rollback and snapshots)
# The other filesystems use persistent ZFS datasets
# Used by hosts via: import ../../disko-zfs.nix { inherit lib; device = "..."; swapSize = "..."; }
{
  device ? throw "Set the disk device, e.g.: /dev/nvme0n1",
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
          # EFI partition for systemd-boot / Limine
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
          # Main LUKS-encrypted partition, containing the ZFS pool
          luks = {
            name = "luks";
            size = "100%";
            content = {
              type = "luks";
              name = "crypted";
              settings = {
                allowDiscards = true;
              };
              # Inside LUKS, the ZFS pool is created directly on the device
              content = {
                type = "zfs";
                pool = "zroot";
              };
            };
          };
        };
      };
    };

    # Main ZFS pool
    zpool.zroot = {
      type = "zpool";
      options = {
        ashift = "12"; # Optimized for disks with 4K sectors (NVMe, modern SSDs)
        autotrim = "on"; # Automatic TRIM for SSDs/NVMe
      };
      rootFsOptions = {
        compression = "zstd"; # Efficient compression for general data
        "com.sun:auto-snapshot" = "false"; # Disable auto-snapshot (managed manually)
        mountpoint = "none"; # Don't mount the root pool directly
        xattr = "sa"; # Extended attributes as system attributes (more efficient)
        acltype = "posixacl"; # POSIX ACLs (required by modern applications)
        dnodesize = "auto"; # Adaptive dnode size (improves compatibility)
      };

      datasets = lib.mkMerge [
        # Swap on ZVOL (only if swapSize != "0")
        # NOTE: ZVOL swap does not support hibernation (suspend-to-disk).
        # For hibernation, use the Btrfs profile (swap on LVM+LUKS with resumeDevice=true).
        (lib.mkIf hasSwap {
          swap = {
            type = "zfs_volume";
            size = swapSize;
            content = {
              type = "swap";
            };
            options = {
              volblocksize = "4096";
              compression = "lz4"; # Lightweight compression for swap (better ratio than zle)
              "com.sun:auto-snapshot" = "false";
            };
          };
        })
        {
          # ── Local datasets (no backup needed — recreatable) ───────────────

          # Container for local datasets
          "local" = {
            type = "zfs_fs";
            options.mountpoint = "none";
          };

          # Ephemeral root — reverted to the @blank snapshot on every boot by the initrd
          # The preservation-zfs.nix module configures automatic rollback via
          # boot.initrd.postDeviceCommands (legacy initrd) or a systemd initrd service.
          "local/root" = {
            type = "zfs_fs";
            mountpoint = "/";
            options = {
              mountpoint = "legacy";
              "com.sun:auto-snapshot" = "false";
            };
            # Blank snapshot created right after formatting; used for rollback on boot
            postCreateHook = "zfs snapshot zroot/local/root@blank";
          };

          # Nix store — preserved (essential for the system to work), no backup
          "local/nix" = {
            type = "zfs_fs";
            mountpoint = "/nix";
            options = {
              mountpoint = "legacy";
              "com.sun:auto-snapshot" = "false";
              atime = "off"; # Disable atime for better performance on /nix
            };
          };

          # ── Safe datasets (persistent data — backup recommended) ──────────

          # Container for persistent datasets
          "safe" = {
            type = "zfs_fs";
            options.mountpoint = "none";
          };

          # User directories — preserved across boots
          "safe/home" = {
            type = "zfs_fs";
            mountpoint = "/home";
            options.mountpoint = "legacy";
          };

          # Persistent system data — used by the preservation module
          "safe/persist" = {
            type = "zfs_fs";
            mountpoint = "/persist";
            options.mountpoint = "legacy";
          };

          # System logs
          "safe/log" = {
            type = "zfs_fs";
            mountpoint = "/var/log";
            options = {
              mountpoint = "legacy";
              compression = "lz4"; # lz4 is efficient for text logs with low overhead
            };
          };

          # Container data (Podman, Docker, etc.) — preserved
          "safe/containers" = {
            type = "zfs_fs";
            mountpoint = "/var/lib/containers";
            options.mountpoint = "legacy";
          };

          # Flatpak apps — preserved across boots
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
