# Overlay local — adiciona pacotes personalizados ao nixpkgs.
# Importado por dendritic/features/local-overlay.nix e propagado a todas as
# nixosConfigurations via config.dendritic.localOverlay. O Home Manager herda
# o overlay automaticamente via home-manager.useGlobalPkgs = true.
final: _prev: {
  run0-sudo = final.callPackage ../pkgs/run0-sudo/package.nix { };
  epson-printer-utility = final.callPackage ../pkgs/epson-printer-utility/package.nix { };
  gregorio-lsp = final.callPackage ../pkgs/gregorio-lsp/package.nix { };
  gregorio-nvim = final.callPackage ../pkgs/gregorio-nvim/package.nix { };
  grefmt = final.gregorio-lsp;
  grelint = final.gregorio-lsp;
  tree-sitter-gregorio = final.callPackage ../pkgs/tree-sitter-gregorio/package.nix { };
  tree-sitter-gregorio-nvim = final.callPackage ../pkgs/tree-sitter-gregorio-nvim/package.nix { };
  # libfprint com drivers Goodix TLS e matcher SIGFM (fork lbssousa, branch goodix-538d-sigfm-gtls)
  libfprint-goodix = final.callPackage ../pkgs/libfprint-goodix/package.nix { };
  # fprintd 1.94.5 compilado contra libfprint-goodix (1.94.10)
  fprintd-goodix = final.callPackage ../pkgs/fprintd-goodix/package.nix { };

  # Brave Origin — variante simplificada do Brave sem recompensas/carteira/IA.
  # Pacote local baseado em https://github.com/NixOS/nixpkgs/pull/513143 (ainda não mesclado).
  brave-origin-beta = final.callPackage ../pkgs/brave-origin/make-brave-origin.nix { } (
    import ../pkgs/brave-origin/brave-origin-beta.nix
  );
  brave-origin-nightly = final.callPackage ../pkgs/brave-origin/make-brave-origin.nix { } (
    import ../pkgs/brave-origin/brave-origin-nightly.nix
  );
}
