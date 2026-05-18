# Módulo nixvim para configuração declarativa do Neovim via Home Manager.
# Inspirado no LazyVim — organizado em camadas importáveis separadamente.
#
# Uso: importe este arquivo no home.nix do usuário:
#   imports = [ ../../../modules/home/apps/editors/nixvim ];
#
# Ao importar, o programs.neovim padrão do common.nix é desabilitado e
# substituído pelo nixvim, que fornece um nvim completo e reprodutível.
{ lib, ... }:

{
  imports = [
    ./core.nix
    ./ui.nix
    ./editor.nix
    ./lsp.nix
    ./git.nix
  ];

  # Desabilita o programs.neovim definido em home/common.nix para evitar
  # conflito de binários e de definição de $EDITOR.
  programs.neovim = {
    enable = lib.mkForce false;
    defaultEditor = lib.mkForce false;
  };

  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };
}
