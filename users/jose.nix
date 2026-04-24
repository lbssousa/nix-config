{ pkgs, lib, ... }:
import ./mkUser.nix { inherit pkgs lib; } {
  username = camelo;
  description = "José Lucas";
}
