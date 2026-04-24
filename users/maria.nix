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

  # Configuração Home Manager para este usuário
  home-manager.users.maria = {
    imports = [ ../home.nix ];
  };
}
