{ pkgs, lib, ... }:
import ./mkUser.nix { inherit pkgs lib; } {
  username = "surubi";
  hasSudo = true;
}
