# Módulo NixOS para definição de usuários pessoais e suas configurações home-manager.
# Substitua "meuusuario" pelo nome de usuário desejado.
{ pkgs, ... }:

{
  # ── Usuário do sistema ──────────────────────────────────────────────────────
  users.users.meuusuario = {
    isNormalUser = true;
    description = "Meu Nome Completo";
    extraGroups = [
      "networkmanager" # Gerenciar conexões de rede
      "wheel" # sudo — remova se não precisar
      "video" # Acesso à GPU
      "audio" # Acesso ao áudio
      "plugdev" # Dispositivos USB
      "dialout" # Portas seriais
      "docker" # Compatibilidade com Docker (Podman)
    ];
    shell = pkgs.zsh;
    # Chaves SSH autorizadas (públicas — seguras para versionar)
    openssh.authorizedKeys.keys = [
      # "ssh-ed25519 AAAA... meu@computador"
    ];
    initialPassword = "nixos"; # Troque no primeiro login
  };

  # ── Persistência de diretórios do usuário (impermanence) ───────────────────
  environment.persistence."/persist" = {
    users.meuusuario = {
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
        ".local/share/flatpak"
        ".var/app"
        ".local/share/containers" # Podman rootless
        ".config/distrobox"
        ".local/share/fish"
      ];
      files = [
        ".bash_history"
        ".zsh_history"
      ];
    };
  };

  # ── Configuração Home Manager ───────────────────────────────────────────────
  # O módulo home-manager já está carregado pelo flake público.
  # Aqui você apenas instancia o usuário e personaliza as preferências.
  home-manager.users.meuusuario = {
    imports = [
      # Módulos públicos reutilizáveis do repo público:
      # ../../home.nix   # Configuração base (pacotes, git, zsh, etc.)

      # Módulos privados adicionais:
      ../home/meuusuario.nix
    ];
  };
}
