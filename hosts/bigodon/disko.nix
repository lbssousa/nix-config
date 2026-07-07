# Disk configuration for bigodon (Morefine M6 Mini-PC)
# Mini-PC with 16 GB RAM - hybrid swap: 20 GB on disk (hibernation) + 8 GB zram
{ lib, ... }:

import ../../disko.nix {
  inherit lib;
  device = "/dev/nvme0n1"; # Adjust as needed (check with: lsblk)
  swapSize = "20G"; # To support hibernation (16 GB RAM + margin)
}
