{ pkgs, lib, ... }:
import ./mkUser.nix { inherit pkgs lib; } {
  username = coruja;
  description = "Miguel Antônio";
}
