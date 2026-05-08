{ pkgs, lib, ... }:
import ./mkUser.nix { inherit pkgs lib; } {
  username = "coelho";
}
