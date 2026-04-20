# Módulo de impermanência: Sistema efêmero com ZFS rollback
# A raiz (/) é limpa a cada boot; dados importantes são preservados em /persist
{ config, lib, pkgs, ... }:

{
  # Rollback do dataset raiz para o snapshot @blank a cada boot
  # Executado no initrd, antes de montar /sysroot
  boot.initrd.systemd.enable = true;
  boot.initrd.systemd.services.rollback = {
    description = "Rollback ZFS root dataset to blank snapshot";
    wantedBy = [ "initrd.target" ];
    after = [ "zfs-import-rpool.service" ];
    before = [ "sysroot.mount" ];
    path = [ pkgs.zfs ];
    unitConfig.DefaultDependencies = "no";
    serviceConfig = {
      Type = "oneshot";
    };
    script = ''
      zfs rollback -r rpool/local/root@blank
    '';
  };

  # Marcar /persist como necessário no boot (impermanence depende disso)
  fileSystems."/persist".neededForBoot = true;

  # Configuração do módulo impermanence
  # Define quais arquivos e diretórios são preservados entre boots
  environment.persistence."/persist" = {
    hideMounts = true;

    # Diretórios do sistema a preservar
    directories = [
      "/etc/nixos"                              # Configuração do NixOS
      "/etc/NetworkManager/system-connections"  # Conexões de rede salvas
      "/var/lib/systemd"                        # Estado do systemd
      "/var/lib/nixos"                          # Estado interno do NixOS
      "/var/lib/bluetooth"                      # Dispositivos Bluetooth pareados
      "/var/db/sudo"                            # Timestamps do sudo
    ];

    # Arquivos do sistema a preservar
    files = [
      "/etc/machine-id"                         # ID único da máquina
    ];
  };

  # Os diretórios de usuário são definidos em modules/users.nix
  # e complementados em hosts/*/configuration.nix
}
