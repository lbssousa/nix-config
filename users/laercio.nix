{ pkgs, ... }:

{
  # Definição do usuário no sistema
  users.users.laercio = {
    isNormalUser = true;
    description = "Laércio Benedito";
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
  home-manager.users.laercio = {
    imports = [
      ../home.nix
      ./laercio-home.nix
    ];
  };
}
