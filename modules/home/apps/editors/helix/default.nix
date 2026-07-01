# Módulo Home Manager: Helix editor
# A configuração do Helix (settings, languages, Gregório/GABC) está em
# packages.helix do flake via nix-wrapper-modules (XDG_CONFIG_HOME embutido).
{ pkgs, flake, ... }:
{
  programs.helix = {
    enable = true;
    # Usa o pacote wrapped do flake: inclui HELIX_RUNTIME com Gregório,
    # LSPs (texlab, gregorio-lsp, zathura) no PATH e config.toml embutido.
    package = flake.packages.${pkgs.stdenv.hostPlatform.system}.helix;
  };
}
