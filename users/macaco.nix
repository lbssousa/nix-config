{ pkgs, lib, ... }:
import ./mkUser.nix { inherit pkgs lib; } {
  username = "macaco";
  uid = 1012;
}
