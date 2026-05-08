_: {
  config.dendritic.localOverlay = final: _prev: {
    epson-printer-utility = final.callPackage ../../pkgs/epson-printer-utility/package.nix { };
    gregorio-lsp = final.callPackage ../../pkgs/gregorio-lsp/package.nix { };
    gregolint = final.gregorio-lsp;
    tree-sitter-gregorio = final.callPackage ../../pkgs/tree-sitter-gregorio/package.nix { };
  };
}
