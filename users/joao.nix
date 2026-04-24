{ pkgs, lib, ... }:
import ./mkUser.nix { inherit pkgs lib; } {
  username = "joao";
  description = "João Felipe";
}
