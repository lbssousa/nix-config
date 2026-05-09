{ pkgs, lib, ... }:
import ./mkUser.nix { inherit pkgs lib; } {
  username = "camelo";
  uid = 1007;
}
