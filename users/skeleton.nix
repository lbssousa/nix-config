# Esqueleto para definição de usuários NixOS (conta do sistema)
# INSTRUÇÕES:
# 1. Copie este arquivo para users/<seu-usuario>.nix
# 2. Substitua "skeleton" pelo nome do usuário desejado
# 3. Ajuste as configurações conforme necessário
# 4. Adicione o arquivo ao índice do git (OBRIGATÓRIO para nixos-install):
#      git add users/<seu-usuario>.nix
#    ⚠️  O Nix avalia flakes a partir do índice git. Arquivos não rastreados
#    (mesmo que existam no disco) são IGNORADOS pelo Nix e não chegam ao
#    /nix/store — causando erros de "módulo não encontrado" no nixos-install.
#    git add inclui o arquivo no índice, tornando-o visível ao Nix.
# 5. Descomente a linha de importação em hosts/<host>/configuration.nix:
#      ./../../users/<seu-usuario>.nix
#
# Para configuração Home Manager personalizada (opcional):
# 6. Crie home/users/<seu-usuario>/home.nix (copie de home/users/laercio/home.nix)
# 7. Adicione a entrada em homeConfigurations no flake.nix:
#      "<seu-usuario>@<host>" = mkHome "<seu-usuario>" "x86_64-linux" [ ./home/users/<seu-usuario>/home.nix ];
#    (para usuários sem customização, a entrada já é gerada automaticamente por mkHomeAllHosts)
#
{ pkgs, lib, ... }:
import ./mkUser.nix { inherit pkgs lib; } {
  username = "skeleton";
  description = "Nome Completo do Usuário";
  # Descomente se o usuário deve ter permissão de sudo:
  # hasSudo = true;
}
