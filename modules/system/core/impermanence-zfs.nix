# Módulo de impermanência para ZFS: Sistema efêmero com dataset ZFS na raiz
# A raiz (/) é um dataset ZFS revertido ao snapshot @blank a cada boot no initrd.
# Isso apaga automaticamente o estado efêmero sem necessidade de tmpfs.
# Dados importantes são preservados em /persist via bind mounts gerenciados pelo
# módulo nix-community/impermanence.
#
# Diferenças em relação ao perfil Btrfs+tmpfs (impermanence.nix):
#   • A raiz usa ZFS (dataset zroot/local/root) em vez de tmpfs
#   • O rollback é feito via boot.initrd.postDeviceCommands (initrd legado)
#     ou via serviço systemd no initrd (quando boot.initrd.systemd.enable = true)
#   • O hostId ZFS (networking.hostId) deve ser definido na configuração do host
#
# Pré-requisitos:
#   • networking.hostId deve ser definido (gerado pelo install.sh ou manualmente:
#     head -c4 /dev/urandom | od -A none -t x4 | tr -d ' ')
#   • O dataset zroot/local/root@blank deve existir (criado pelo disko-zfs.nix)
{ lib, ... }:

{
  # Habilitar suporte a ZFS no kernel e nas ferramentas de espaço de usuário
  boot.supportedFilesystems = [ "zfs" ];

  # Rollback do dataset raiz ao snapshot @blank no initrd legado (não-systemd).
  # lib.mkAfter garante que este comando executa APÓS a importação do pool ZFS
  # pelo initrd (que acontece nos postDeviceCommands padrão do NixOS com ZFS).
  #
  # Para sistemas com boot.initrd.systemd.enable = true, comente este bloco e
  # use o serviço systemd abaixo (boot.initrd.systemd.services.rollback).
  boot.initrd.postDeviceCommands = lib.mkAfter ''
    zfs rollback -r zroot/local/root@blank
  '';

  # Alternativa para initrd systemd (boot.initrd.systemd.enable = true):
  # Descomente o bloco abaixo e comente o boot.initrd.postDeviceCommands acima.
  #
  # boot.initrd.systemd.services.rollback = {
  #   description = "Rollback do dataset raiz ZFS para o snapshot @blank";
  #   wantedBy = [ "initrd.target" ];
  #   after = [ "zfs-import-zroot.service" ];
  #   before = [ "sysroot.mount" ];
  #   unitConfig.DefaultDependencies = "no";
  #   serviceConfig.Type = "oneshot";
  #   script = ''
  #     zfs rollback -r zroot/local/root@blank
  #   '';
  # };

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
      # NOTA: /etc/shadow NÃO é gerenciado aqui.
      # O módulo de usuários (users.nix) define um activation script 'restoreShadow'
      # com deps = ["users"] que, após o script de ativação 'users' do NixOS
      # (que faz rename atômico de /etc/shadow quebrando bind mounts anteriores),
      # re-estabelece o bind mount /persist/etc/shadow → /etc/shadow. Isso garante que
      # alterações de senha via 'passwd' sejam persistidas em /persist/etc/shadow.
    ];
  };

  # Os diretórios de usuário são definidos em modules/system/users/users.nix
  # e complementados em hosts/*/configuration.nix
}
