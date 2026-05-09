# Overlay local — adiciona pacotes personalizados ao nixpkgs.
# Importado por dendritic/features/local-overlay.nix e propagado a todas as
# nixosConfigurations e homeConfigurations via config.dendritic.localOverlay.
final: _prev: {
  epson-printer-utility = final.callPackage ../pkgs/epson-printer-utility/package.nix { };
  gregorio-lsp = final.callPackage ../pkgs/gregorio-lsp/package.nix { };
  gregolint = final.gregorio-lsp;
  tree-sitter-gregorio = final.callPackage ../pkgs/tree-sitter-gregorio/package.nix { };
}
