{ pkgs, lib, ... }:
import ./mkUser.nix { inherit pkgs lib; } {
  username = "gorila";
  uid = 1006;
}
