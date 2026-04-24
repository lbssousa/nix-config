{ pkgs, lib, ... }:
import ./mkUser.nix { inherit pkgs lib; } {
  username = cavalo;
  description = "João Felipe";
}
