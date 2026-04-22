# flake.nix do repositório privado (nixos-config-private).
# Este flake é OPCIONAL — o repo público não o importa como input.
# Seu propósito principal é permitir que o repo privado seja
# versionado e compartilhado entre máquinas pessoais de forma reproduzível.
#
# O ponto de integração com o público é o arquivo modules.nix na raiz,
# importado pelo flake público via builtins.pathExists ./private/modules.nix.
{
  description = "Camada privada do nixos-config (usuários, homes e segredos)";

  inputs = {
    # Referência ao repo público — útil para acessar seus módulos/overlays.
    # Deixe comentado se não precisar importar nada do público aqui.
    # nixos-config.url = "github:lbssousa/nixos-config";
  };

  outputs = _: {
    # Este flake não exporta saídas — ele apenas existe para versionamento.
    # A integração real acontece pelo arquivo modules.nix importado diretamente
    # pelo flake público quando ./private está presente.
  };
}
