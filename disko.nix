# Base Btrfs partitioning template with LUKS + LVM
# The root (/) uses tmpfs (always clean on boot — no snapshot/rollback needed)
# The other filesystems use Btrfs subvolumes (persistent data)
# Used by hosts via: import ../../disko.nix { inherit lib; device = "..."; swapSize = "..."; }
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
    # Ephemeral root: tmpfs — automatically wiped every boot, no rollback needed
    # preservation keeps important files persistent via bind mounts from /persist
    nodev."/" = {
      fsType = "tmpfs";
      mountOptions = [
        "defaults"
        "size=50%" # 50% of RAM; adjust as needed
        "mode=755"
      ];
    };

    disk.main = {
      inherit device;
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          # EFI partition for systemd-boot
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
          # Main LUKS-encrypted partition
          luks = {
            name = "luks";
            size = "100%";
            content = {
              type = "luks";
              name = "crypted";
              settings = {
                allowDiscards = true;
              };
              # Inside LUKS, use LVM for swap + Btrfs volume
              content = {
                type = "lvm_pv";
                vg = "root_vg";
              };
            };
          };
        };
      };
    };

    # LVM volume group inside LUKS
    lvm_vg.root_vg = {
      type = "lvm_vg";
      lvs = lib.mkMerge [
        # Disk swap (only if swapSize != "0")
        (lib.mkIf hasSwap {
          swap = {
            size = swapSize;
            content = {
              type = "swap";
              resumeDevice = true; # Hibernation support
            };
          };
        })
        # Logical volume for the Btrfs filesystem
        {
          root = {
            size = "100%FREE";
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ]; # Force creation (overwrites existing fs if needed)

              subvolumes = {
                # Nix store — preserved (essential for the system to work)
                "@nix" = {
                  mountpoint = "/nix";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };

                # Persistent system data — used by the preservation module
                "@persist" = {
                  mountpoint = "/persist";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };

                # System logs — no compression (logs are already compressed internally)
                "@log" = {
                  mountpoint = "/var/log";
                  mountOptions = [ "noatime" ];
                };

                # Container data (Podman, Docker, etc.) — preserved
                "@containers" = {
                  mountpoint = "/var/lib/containers";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };

                # Flatpak apps — preserved across boots
                "@flatpak" = {
                  mountpoint = "/var/lib/flatpak";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };

                # Btrfs snapshots — for future backups (snapper, timeshift, etc.)
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
