{ pkgs, lib, ... }:
lib.mkMerge [
  (import ./mkUser.nix { inherit pkgs lib; } {
    username = "abutre";
    uid = 1000;
    hasSudo = true;
  })

  {
    security.keepassxc.autoLockOnYubikeyRemove.users = [ "abutre" ];
  }
]
