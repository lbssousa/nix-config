{ pkgs, lib, ... }:
import ./mkUser.nix { inherit pkgs lib; } {
  username = "coruja";
  uid = 1010;
}
