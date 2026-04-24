{ pkgs, lib, ... }:
import ./mkUser.nix { inherit pkgs lib; } {
  username = surubi;
  description = "Roberta Priscila";
  hasSudo = true;
}
