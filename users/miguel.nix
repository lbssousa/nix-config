{ pkgs, ... }:

{
  # Definição do usuário no sistema
  users.users.miguel = {
    isNormalUser = true;
    description = "Miguel Antônio";
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
  home-manager.users.coruja = {
    imports = [ ../home.nix ];
  };
}
