# Esqueleto para definição de usuários
# INSTRUÇÕES:
# 1. Copie este arquivo para users/<seu-usuario>.nix
# 2. Substitua "skeleton" pelo nome do usuário desejado
# 3. Ajuste as configurações conforme necessário
# 4. Adicione o arquivo ao índice do git (OBRIGATÓRIO para nixos-install):
#      git add --force users/<seu-usuario>.nix
#    ⚠️  O Nix avalia flakes a partir do índice git. Arquivos não rastreados
#    (mesmo que existam no disco) são IGNORADOS pelo Nix e não chegam ao
#    /nix/store — causando erros de "módulo não encontrado" no nixos-install.
#    git add --force inclui o arquivo no índice sem fazer commit,
#    tornando-o visível ao Nix sem expô-lo no histórico do repositório.
# 5. Descomente a linha de importação em hosts/<host>/configuration.nix:
#      ./../../users/<seu-usuario>.nix
#
# NOTA: Os arquivos em users/ (exceto este skeleton) são ignorados pelo git.
# Veja .gitignore para mais detalhes.
{ pkgs, ... }:

{
  # Definição do usuário no sistema
  users.users.skeleton = {
    isNormalUser = true;
    description = "Nome Completo do Usuário";
    # Grupos essenciais para desktop com GNOME + containers
    extraGroups = [
      "networkmanager" # Gerenciar conexões de rede
      # Remova "wheel" abaixo se o usuário NÃO deve ter permissão de sudo:
      "wheel" # sudo
      "video" # Acesso à GPU
      "audio" # Acesso ao áudio
      "plugdev" # Acesso a dispositivos USB
      "dialout" # Portas seriais
      "docker" # Compatibilidade com Docker (Podman)
    ];
    shell = pkgs.zsh; # Shell padrão (Zsh)
    # Senha inicial: o usuário será solicitado a trocá-la no primeiro login.
    # Se uma senha personalizada for definida durante a instalação (ver INSTALLATION.md),
    # a troca não será exigida.
    initialPassword = "nixos";
  };

  # Diretórios do usuário a preservar entre boots (via impermanence)
  environment.persistence."/persist" = {
    users.skeleton = {
      directories = [
        "Downloads"
        "Documents"
        "Pictures"
        "Videos"
        "Music"
        ".ssh"
        ".gnupg"
        ".local/share/keyrings" # GNOME Keyring
        ".config/gh" # GitHub CLI
        ".local/share/flatpak" # Dados de Flatpaks do usuário
        ".var/app" # Dados de Flatpaks (XDG)
        ".local/share/containers" # Podman rootless
        ".config/distrobox" # Distrobox
        ".local/share/fish" # Histórico do Fish shell
      ];
      files = [
        ".bash_history"
        ".zsh_history"
      ];
    };
  };

  # Configuração Home Manager para este usuário
  home-manager.users.skeleton = {
    imports = [
      ../home.nix
      # Módulos de usuário opcionais (descomente conforme necessário):
      # ../modules/user/apps/brave.nix   # Brave Browser via nixpkgs
    ];
  };
}
