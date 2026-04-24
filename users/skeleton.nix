# Esqueleto para definição de usuários
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
{ pkgs, lib, ... }:
import ./mkUser.nix { inherit pkgs lib; } {
  username = "skeleton";
  description = "Nome Completo do Usuário";
  # Descomente se o usuário deve ter permissão de sudo:
  # hasSudo = true;
  # Módulos Home Manager adicionais (descomente conforme necessário):
  # extraHomeImports = [
  #   ./skeleton-home.nix
  #   ../modules/user/apps/brave.nix  # Brave Browser via nixpkgs
  # ];
}
