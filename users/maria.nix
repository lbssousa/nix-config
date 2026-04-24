{ pkgs, lib, ... }:
import ./mkUser.nix { inherit pkgs lib; } {
  username = "maria";
  description = "Maria Rita";
}
