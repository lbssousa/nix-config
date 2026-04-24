{ pkgs, ... }:

{
  # Definição do usuário no sistema
  users.users.joao = {
    isNormalUser = true;
    description = "João Felipe";
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
  home-manager.users.joao = {
    imports = [ ../home.nix ];
  };
}
