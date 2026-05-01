{ config, inputs, ... }:
let
  inherit (inputs.nixpkgs) lib;
in
{
  flake.diskoConfigurations = lib.mapAttrs (
    hostname: _hostSpec:
    import ../../hosts/${hostname}/disko.nix { inherit (inputs.nixpkgs) lib; }
  ) config.dendritic.hosts;
}
