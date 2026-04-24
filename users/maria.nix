{ pkgs, ... }:

{
  # Definição do usuário no sistema
  users.users.maria = {
    isNormalUser = true;
    description = "Maria Rita";
    extraGroups = [
      "networkmanager"
      "video"
      "audio"
      "plugdev"
      "dialout"
      "docker"
    ];
    shell = pkgs.zsh;
    initialPassword = "nixos";
  };

  # Diretórios do usuário a preservar entre boots (via impermanence)
  environment.persistence."/persist" = {
    users.maria = {
      directories = [
        "Downloads"
        "Documents"
        "Pictures"
        "Videos"
        "Music"
        ".ssh"
        ".gnupg"
        ".local/share/keyrings" # GNOME Keyring
        ".config/sops/age" # Chave age do usuário para uso do CLI sops
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

  # Configuração Home Manager para este usuário
  home-manager.users.macaco = {
    imports = [ ../home.nix ];
  };
}
