{ pkgs, lib, ... }:
import ./mkUser.nix { inherit pkgs lib; } {
  username = "surubi";
  uid = 1001;
}
