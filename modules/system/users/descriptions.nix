# NixOS module: sets the GECOS field (/etc/passwd) with each user's full
# name, read from nix-secrets as a flake output.
#
# Usage (in dendritic/features/nixos-modules.nix):
#   import ../../modules/system/users/descriptions.nix { inherit inputs; users = config.dendritic.users; }
{ inputs, users }:
{ lib, ... }:
{
  users.users = lib.genAttrs users (username: {
    description = inputs.nix-secrets.${username}.fullName;
  });
}
