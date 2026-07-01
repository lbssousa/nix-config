# Configuração de disco para barbudus (Dell Inspiron 14 5490)
# Laptop com 16 GB RAM - swap híbrida: 20 GB em disco (hibernação) + 8 GB zram
{ lib, ... }:

import ../../disko.nix {
  inherit lib;
  device = "/dev/nvme0n1"; # Ajuste conforme necessário (verifique com: lsblk)
  swapSize = "20G"; # Para suportar hibernação (16 GB RAM + margem)
}
