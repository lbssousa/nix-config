# Configura o pkgs para todos os módulos perSystem com o overlay local aplicado.
# Sem isso, pkgs.tree-sitter-gregorio, pkgs.gregorio-lsp etc. não seriam
# acessíveis em helix-wrapper.nix e demais módulos perSystem.
{ inputs, ... }:
{
  perSystem =
    { system, ... }:
    {
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [ (import ../../overlays) ];
      };
    };
}
