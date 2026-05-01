{ ... }:
{
  config.dendritic.localOverlay = final: _prev: {
    epson-printer-utility = final.callPackage ../../pkgs/epson-printer-utility/package.nix { };
  };
}
