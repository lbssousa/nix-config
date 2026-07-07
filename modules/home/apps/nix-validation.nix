# User module: tools for validating and formatting Nix files
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # Formatting
    nixfmt
    alejandra
    nixpkgs-fmt

    # Lint / static analysis
    statix
    deadnix

    # LSP for editor
    nil
    nixd
  ];
}
