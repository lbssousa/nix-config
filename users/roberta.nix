{ pkgs, lib, ... }:
import ./mkUser.nix { inherit pkgs lib; } {
  username = "roberta";
  description = "Roberta Priscila";
  hasSudo = true;
}
