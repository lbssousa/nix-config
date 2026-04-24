{ pkgs, ... }:

{
  # Definição do usuário no sistema
  users.users.laercio = {
    isNormalUser = true;
    description = "abutre";
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
  home-manager.users.abutre = {
    imports = [
      ../home.nix
      ./laercio-home.nix
    ];
  };
}
