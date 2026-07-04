# Módulo de preservação: Sistema efêmero com tmpfs na raiz
# A raiz (/) é um tmpfs — limpa automaticamente a cada boot sem necessidade
# de rollback ou snapshot. Dados importantes são preservados em /persist via
# bind mounts gerenciados pelo módulo nix-community/preservation.
#
# /home também é tmpfs (sem subvolume Btrfs próprio). Os itens selecionados de
# cada usuário são bind-montados de /persist/home/<usuario>/. O restante do
# diretório home — symlinks gerenciados pelo Home Manager, arquivos de cache,
# etc. — é efêmero e recriado a cada boot.
#
# A lista de itens preservados por usuário é definida em users/mkUser.nix.
_:

{
  # /persist deve estar disponível no boot (o módulo preservation precisa dele
  # para configurar os bind mounts antes de qualquer serviço iniciar)
  fileSystems."/persist".neededForBoot = true;

  preservation.enable = true;

  preservation.preserveAt."/persist" = {
    directories = [
      # Symlinks: aplicações lêem via stat() normal e seguem symlinks sem restrições
      { directory = "/etc/nixos"; how = "symlink"; } # Configuração do NixOS
      { directory = "/etc/NetworkManager/system-connections"; how = "symlink"; } # Conexões de rede salvas
      { directory = "/var/lib/nixos"; how = "symlink"; } # Estado interno do NixOS
      # Bind-mounts: aplicações usam lstat() ou têm restrições de segurança
      "/var/lib/bluetooth" # Bind-mount obrigatório: StateDirectory= do bluetoothd falha com symlink no systemd 256+
      "/var/lib/fprint"    # Idem: fprintd usa StateDirectory=fprint com namespace isolation
      "/var/lib/systemd" # Estado do systemd — sensível ao próprio diretório
      "/var/db/sudo" # Timestamps do sudo — sudo usa lstat() por segurança
    ];

    files = [
      # inInitrd: machine-id é lido pelo systemd-journald antes de qualquer mount regular
      { file = "/etc/machine-id"; inInitrd = true; } # ID único da máquina
      # NOTA: /etc/shadow NÃO é gerenciado aqui.
      # O módulo de usuários (users.nix) define um activation script 'restoreShadow'
      # com deps = ["users"] que, após o script de ativação 'users' do NixOS
      # (que faz rename atômico de /etc/shadow), copia /persist/etc/shadow →
      # /etc/shadow. Isso garante que alterações de senha via 'passwd' sejam
      # persistidas em /persist/etc/shadow.
    ];
  };

  # /etc/machine-id é bind-montado do btrfs (@persist) pelo preservation no initrd.
  # O systemd-machine-id-commit.service destina-se a "commitar" um machine-id
  # transiente (tmpfs do initrd) para disco — não se aplica aqui pois o arquivo
  # já é persistente. A condição ConditionPathIsMountPoint=/etc/machine-id dispara
  # o serviço (pois É um mount point), mas --commit falha ("not on a temporary file
  # system"). O drop-in abaixo inverte a condição para suprimir a execução.
  systemd.services."systemd-machine-id-commit" = {
    overrideStrategy = "asDropin";
    unitConfig = {
      ConditionPathIsMountPoint = [ "" "!/etc/machine-id" ];
    };
  };
}
