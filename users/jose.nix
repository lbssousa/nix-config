{ pkgs, ... }:

{
  # Definição do usuário no sistema
  users.users.jose = {
    isNormalUser = true;
    description = "José Lucas";
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

  # Configuração Home Manager para este usuário
  home-manager.users.jose = {
    imports = [ ../home.nix ];
  };
}
