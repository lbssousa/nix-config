# Home Manager module: Helix editor
# The Helix configuration (settings, languages, Gregorio/GABC) lives in
# packages.helix from the flake via nix-wrapper-modules (XDG_CONFIG_HOME baked in).
{ pkgs, flake, ... }:
{
  programs.helix = {
    enable = true;
    # Uses the wrapped package from the flake: includes HELIX_RUNTIME with
    # Gregorio, LSPs (texlab, gregorio-lsp, zathura) on PATH and an embedded config.toml.
    package = flake.packages.${pkgs.stdenv.hostPlatform.system}.helix;
  };
}
