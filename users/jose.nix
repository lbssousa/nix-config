{ pkgs, lib, ... }:
import ./mkUser.nix { inherit pkgs lib; } {
  username = "jose";
  description = "José Lucas";
}
