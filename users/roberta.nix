{ pkgs, ... }:

{
  # Definição do usuário no sistema
  users.users.roberta = {
    isNormalUser = true;
    description = "Roberta Priscila";
    extraGroups = [
      "networkmanager"
      "wheel" # sudo
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
  home-manager.users.roberta = {
    imports = [ ../home.nix ];
  };
}
