# Módulo de impermanência: Sistema efêmero com tmpfs na raiz
# A raiz (/) é um tmpfs — limpa automaticamente a cada boot sem necessidade
# de rollback ou snapshot. Dados importantes são preservados em /persist via
# bind mounts gerenciados pelo módulo nix-community/impermanence.
_:

{
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
