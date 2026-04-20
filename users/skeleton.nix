# Esqueleto para definição de usuários
# INSTRUÇÕES:
# 1. Copie este arquivo para users/<seu-usuario>.nix
# 2. Substitua "skeleton" pelo nome do usuário desejado
# 3. Ajuste as configurações conforme necessário
# 4. Importe o arquivo no flake.nix ou na configuration.nix do host
#
# NOTA: Os arquivos em users/ (exceto este skeleton) são ignorados pelo git.
# Veja .gitignore para mais detalhes.
{ config, lib, pkgs, ... }:

{
  # Definição do usuário no sistema
  users.users.skeleton = {
    isNormalUser = true;
    description = "Nome Completo do Usuário";
    # Grupos essenciais para desktop com GNOME + containers
    extraGroups = [
      "networkmanager"  # Gerenciar conexões de rede
      "wheel"           # sudo
      "video"           # Acesso à GPU
      "audio"           # Acesso ao áudio
      "plugdev"         # Acesso a dispositivos USB
      "dialout"         # Portas seriais
      "docker"          # Compatibilidade com Docker (Podman)
    ];
    shell = pkgs.zsh; # Shell padrão (Zsh)
    # IMPORTANTE: Não defina senha aqui!
    # Após a instalação, execute: passwd <usuario>
    # Ou use hashedPasswordFile para carregar de /persist
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
        ".local/share/keyrings"   # GNOME Keyring
        ".config/gh"              # GitHub CLI
        ".local/share/flatpak"    # Dados de Flatpaks do usuário
        ".var/app"                # Dados de Flatpaks (XDG)
        ".local/share/containers" # Podman rootless
        ".config/distrobox"       # Distrobox
        ".local/share/fish"       # Histórico do Fish shell
      ];
      files = [
        ".bash_history"
        ".zsh_history"
      ];
    };
  };

  # Configuração Home Manager para este usuário
  home-manager.users.skeleton = import ../home.nix;
}
