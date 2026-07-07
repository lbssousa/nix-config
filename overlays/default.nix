# Local overlay — adds custom packages to nixpkgs.
# Imported by dendritic/features/local-overlay.nix and propagated to all
# nixosConfigurations via config.dendritic.localOverlay. Home Manager
# inherits the overlay automatically via home-manager.useGlobalPkgs = true.
final: _prev: {
  run0-sudo = final.callPackage ../pkgs/run0-sudo/package.nix { };
  epson-printer-utility = final.callPackage ../pkgs/epson-printer-utility/package.nix { };
  gregorio-lsp = final.callPackage ../pkgs/gregorio-lsp/package.nix { };
  gregorio-nvim = final.callPackage ../pkgs/gregorio-nvim/package.nix { };
  grefmt = final.gregorio-lsp;
  grelint = final.gregorio-lsp;
  tree-sitter-gregorio = final.callPackage ../pkgs/tree-sitter-gregorio/package.nix { };
  tree-sitter-gregorio-nvim = final.callPackage ../pkgs/tree-sitter-gregorio-nvim/package.nix { };
  # libfprint with Goodix TLS drivers and SIGFM matcher (lbssousa fork, goodix-538d-sigfm-gtls branch)
  libfprint-goodix = final.callPackage ../pkgs/libfprint-goodix/package.nix { };
  # fprintd 1.94.5 built against libfprint-goodix (1.94.10)
  fprintd-goodix = final.callPackage ../pkgs/fprintd-goodix/package.nix { };

  # Brave Origin — simplified Brave variant without rewards/wallet/AI.
  # Local package based on https://github.com/NixOS/nixpkgs/pull/513143 (not yet merged).
  brave-origin-beta = final.callPackage ../pkgs/brave-origin/make-brave-origin.nix { } (
    import ../pkgs/brave-origin/brave-origin-beta.nix
  );
  brave-origin-nightly = final.callPackage ../pkgs/brave-origin/make-brave-origin.nix { } (
    import ../pkgs/brave-origin/brave-origin-nightly.nix
  );
}
