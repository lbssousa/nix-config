# Configures pkgs for all perSystem modules with the local overlay applied.
# Without this, pkgs.tree-sitter-gregorio, pkgs.gregorio-lsp etc. would not be
# accessible in helix-wrapper.nix and other perSystem modules.
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
