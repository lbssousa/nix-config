{ inputs, ... }:
{
  # Expose disko configurations for standalone partitioning
  flake.diskoConfigurations = {
    barbudus = import ../hosts/barbudus/disko.nix { inherit (inputs.nixpkgs) lib; };
    bigodon = import ../hosts/bigodon/disko.nix { inherit (inputs.nixpkgs) lib; };
  };
}
