# Módulo de impermanência: Sistema efêmero com ZFS rollback
# A raiz (/) é limpa a cada boot; dados importantes são preservados em /persist
{ pkgs, ... }:

{
  # Rollback do dataset raiz para o snapshot @blank a cada boot
  # Executado no initrd, antes de montar /sysroot
  # NOTA: O nome do pool ZFS está hardcoded como "rpool" para corresponder ao disko.nix
  # Se alterar poolName em disko.nix, atualize também o nome aqui
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
    ];
  };

  # Os diretórios de usuário são definidos em modules/users.nix
  # e complementados em hosts/*/configuration.nix
}
