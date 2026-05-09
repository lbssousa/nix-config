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
# 5. O módulo é carregado automaticamente via dendritic/data/users.nix —
#    basta adicionar o nome de usuário à lista.
#
# Para configuração Home Manager personalizada (opcional):
# 6. Crie home/users/<seu-usuario>/home.nix (copie de home/users/abutre/home.nix)
# 7. Adicione-o ao índice do git:
#      git add home/users/<seu-usuario>/home.nix
#    O módulo home-manager.nix detecta automaticamente o arquivo via
#    lib.pathExists e o importa sem nenhuma alteração adicional no flake.
#
{ pkgs, lib, ... }:
import ./mkUser.nix { inherit pkgs lib; } {
  username = "skeleton";
  # Descomente se o usuário deve ter permissão de sudo:
  # hasSudo = true;
}
