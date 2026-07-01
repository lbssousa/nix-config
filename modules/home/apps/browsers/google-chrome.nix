# Módulo de usuário: Google Chrome via módulo nativo do Home Manager
{ pkgs, ... }:

{
  programs.google-chrome = {
    enable = true;
    package = pkgs.google-chrome;
  };

}
