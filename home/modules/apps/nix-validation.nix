# Módulo de usuário: Ferramentas para validação e formatação de arquivos Nix
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # Formatação
    nixfmt
    alejandra
    nixpkgs-fmt

    # Lint / análise estática
    statix
    deadnix

    # LSP para editor
    nil
    nixd
  ];
}
