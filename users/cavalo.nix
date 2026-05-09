{ pkgs, lib, ... }:
import ./mkUser.nix { inherit pkgs lib; } {
  username = "cavalo";
  uid = 1004;
}
