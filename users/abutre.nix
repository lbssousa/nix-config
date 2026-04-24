{ pkgs, lib, ... }:
import ./mkUser.nix { inherit pkgs lib; } {
  username = abutre;
  description = "abutre";
  hasSudo = true;
  extraHomeImports = [ ./abutre-home.nix ];
}
