{ inputs, ... }:
{
  config.dendritic.localOverlay = import ../../overlays { inherit inputs; };
}
