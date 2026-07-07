# Skeleton for defining NixOS users (system account)
# INSTRUCTIONS:
# 1. Copy this file to users/<your-username>.nix
# 2. Replace "skeleton" with the desired username
# 3. Adjust the settings as needed
# 4. Add the file to the git index (REQUIRED for nixos-install):
#      git add users/<your-username>.nix
#    ⚠️  Nix evaluates flakes from the git index. Untracked files (even if
#    they exist on disk) are IGNORED by Nix and never reach the
#    /nix/store — causing "module not found" errors in nixos-install.
#    git add includes the file in the index, making it visible to Nix.
# 5. The module is loaded automatically via dendritic/data/users.nix —
#    just add the username to the list.
#
# For custom Home Manager configuration (optional):
# 6. Create home/users/<your-username>/home.nix (copy from home/users/abutre/home.nix)
# 7. Add it to the git index:
#      git add home/users/<your-username>/home.nix
#    The home-manager.nix module automatically detects the file via
#    lib.pathExists and imports it with no further changes to the flake needed.
#
{ pkgs, lib, ... }:
import ./mkUser.nix { inherit pkgs lib; } {
  username = "skeleton";
  # Uncomment if the user should have sudo permission:
  # hasSudo = true;
}
