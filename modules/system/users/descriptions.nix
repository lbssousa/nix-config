# Fábrica de módulo NixOS: define o campo GECOS (/etc/passwd) com o nome
# completo de cada usuário, lido de nix-secrets/secrets.yaml (cifrado).
#
# Uso (em dendritic/features/nixos-modules.nix):
#   import ../../modules/system/users/descriptions.nix { inherit inputs; users = config.dendritic.users; }
#
# A lista `users` é passada no nível flake-parts (onde config.dendritic.users
# está disponível) e fechada antes de chegar ao nixosSystem, contornando a
# ausência de config.dendritic dentro do módulo NixOS.
{ inputs, users }:
{ lib, pkgs, ... }:
{
  # Declara segredos sops para os nomes completos de todos os usuários.
  sops.secrets = lib.listToAttrs (
    map (username: {
      name = "${username}-full-name";
      value = {
        sopsFile = inputs.nix-secrets + "/secrets.yaml";
        key = "${username}/full_name";
      };
    }) users
  );

  # Preenche o campo GECOS (/etc/passwd) com o nome completo descriptografado.
  # Roda após 'users' (que regenera /etc/passwd) e após 'setupSecrets'.
  system.activationScripts.userDescriptions = {
    deps = [
      "setupSecrets"
      "users"
    ];
    text = lib.concatMapStrings (username: ''
      if [ -f /run/secrets/${username}-full-name ]; then
        ${pkgs.shadow}/bin/usermod -c "$(cat /run/secrets/${username}-full-name)" ${lib.escapeShellArg username} 2>/dev/null || true
      fi
    '') users;
  };
}
