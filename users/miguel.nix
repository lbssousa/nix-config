{ pkgs, lib, ... }:
import ./mkUser.nix { inherit pkgs lib; } {
  username = "miguel";
  description = "Miguel Antônio";
}
