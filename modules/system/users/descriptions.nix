# Módulo NixOS: define o campo GECOS (/etc/passwd) com o nome
# completo de cada usuário, lido de nix-secrets como output do flake.
#
# Uso (em dendritic/features/nixos-modules.nix):
#   import ../../modules/system/users/descriptions.nix { inherit inputs; users = config.dendritic.users; }
{ inputs, users }:
{ lib, ... }:
{
  users.users = lib.genAttrs users (
    username: { description = inputs.nix-secrets.${username}.fullName; }
  );
}
