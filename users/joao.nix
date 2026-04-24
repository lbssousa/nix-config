{ pkgs, ... }:

{
  # Definição do usuário no sistema
  users.users.joao = {
    isNormalUser = true;
    description = "João";
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
    users.joao = {
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
  home-manager.users.cavalo = {
    imports = [
      ../home.nix
      # Módulos de usuário opcionais (descomente conforme necessário):
      # ../modules/user/apps/brave.nix   # Brave Browser via nixpkgs
    ];
  };
}
