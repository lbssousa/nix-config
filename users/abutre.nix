{ pkgs, lib, ... }:
lib.mkMerge [
  (import ./mkUser.nix { inherit pkgs lib; } {
    username = "abutre";
    hasSudo = true;
  })

  {
    security.keepassxc.autoLockOnYubikeyRemove.users = [ "abutre" ];
  }
]
