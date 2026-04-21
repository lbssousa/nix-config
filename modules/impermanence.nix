# Módulo de impermanência: Sistema efêmero com Btrfs rollback
# A raiz (/) é limpa a cada boot; dados importantes são preservados em /persist
{ pkgs, ... }:

{
  # Rollback do subvolume raiz (@) para o snapshot @blank a cada boot
  # Executado no initrd, antes de montar /sysroot
  # O rollback consiste em:
  #   1. Montar o volume Btrfs bruto (sem subvolume) em /btrfs_tmp
  #   2. Deletar o subvolume @ atual
  #   3. Criar um novo @ a partir do snapshot somente-leitura @blank
  #   4. Desmontar /btrfs_tmp
  # O snapshot @blank é criado durante a instalação (ver scripts/install.sh, passo 4)
  boot.initrd.systemd.enable = true;
  boot.initrd.supportedFilesystems = [ "btrfs" ];
  boot.initrd.systemd.services.rollback = {
    description = "Rollback Btrfs root subvolume to blank snapshot";
    wantedBy = [ "initrd.target" ];
    after = [ "systemd-cryptsetup@crypted.service" ];
    before = [ "sysroot.mount" ];
    path = [ pkgs.btrfs-progs ];
    unitConfig.DefaultDependencies = "no";
    serviceConfig = {
      Type = "oneshot";
    };
    script = ''
      mkdir -p /btrfs_tmp
      mount -t btrfs -o subvol=/ /dev/root_vg/root /btrfs_tmp

      if [[ -e /btrfs_tmp/@ ]]; then
        btrfs subvolume delete /btrfs_tmp/@
      fi
      btrfs subvolume snapshot /btrfs_tmp/@blank /btrfs_tmp/@

      umount /btrfs_tmp
    '';
  };

  # Marcar /persist e /home como necessários no boot (impermanence depende disso)
  fileSystems = {
    "/persist".neededForBoot = true;
    "/home".neededForBoot = true;
  };

  # Configuração do módulo impermanence
  # Define quais arquivos e diretórios são preservados entre boots
  environment.persistence."/persist" = {
    hideMounts = true;

    # Diretórios do sistema a preservar
    directories = [
      "/etc/nixos" # Configuração do NixOS
      "/etc/NetworkManager/system-connections" # Conexões de rede salvas
      "/var/lib/systemd" # Estado do systemd
      "/var/lib/nixos" # Estado interno do NixOS
      "/var/lib/bluetooth" # Dispositivos Bluetooth pareados
      "/var/db/sudo" # Timestamps do sudo
    ];

    # Arquivos do sistema a preservar
    files = [
      "/etc/machine-id" # ID único da máquina
      "/etc/shadow" # Hashes de senha dos usuários
    ];
  };

  # Os diretórios de usuário são definidos em modules/users.nix
  # e complementados em hosts/*/configuration.nix
}
