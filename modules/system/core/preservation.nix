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

  preservation.preserveAt."/persist" = {
    directories = [
      "/etc/nixos" # Configuração do NixOS
      "/etc/NetworkManager/system-connections" # Conexões de rede salvas
      "/var/lib/systemd" # Estado do systemd
      "/var/lib/nixos" # Estado interno do NixOS
      "/var/lib/bluetooth" # Dispositivos Bluetooth pareados
      "/var/db/sudo" # Timestamps do sudo
    ];

    files = [
      "/etc/machine-id" # ID único da máquina
      # NOTA: /etc/shadow NÃO é gerenciado aqui.
      # O módulo de usuários (users.nix) define um activation script 'restoreShadow'
      # com deps = ["users"] que, após o script de ativação 'users' do NixOS
      # (que faz rename atômico de /etc/shadow), copia /persist/etc/shadow →
      # /etc/shadow. Isso garante que alterações de senha via 'passwd' sejam
      # persistidas em /persist/etc/shadow.
    ];
  };
}
