{ ... }:
{
  config.dendritic.localOverlay = final: _prev: {
    epson-printer-utility = final.callPackage ../../pkgs/epson-printer-utility/package.nix { };
    gregolint = final.callPackage ../../pkgs/gregolint/package.nix { };
    gregorio-lsp = final.callPackage ../../pkgs/gregorio-lsp/package.nix {
      inherit (final) gregolint;
    };
    tree-sitter-gregorio = final.callPackage ../../pkgs/tree-sitter-gregorio/package.nix { };
    zed-gregorio = final.callPackage ../../pkgs/zed-gregorio/package.nix { };
  };
}
