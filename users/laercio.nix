{ pkgs, lib, ... }:
import ./mkUser.nix { inherit pkgs lib; } {
  username = "laercio";
  description = "Laércio Benedito";
  hasSudo = true;
}
