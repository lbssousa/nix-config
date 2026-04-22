# Ponto de entrada da camada privada.
# Este arquivo é importado pelo flake público quando ./private/modules.nix existe.
# Retorna uma lista de módulos NixOS — cada módulo pode definir usuários,
# configurações home-manager, segredos e qualquer outra opção NixOS.
#
# IMPORTANTE: Após clonar este repositório em ./private, execute:
#   git add --force private/
# para tornar os arquivos visíveis ao Nix sem commitá-los.
[
  # Definições de usuários do sistema (users.users.*) e configurações
  # do home-manager (home-manager.users.*) para cada usuário pessoal.
  ./nixos/users.nix

  # Adicione mais módulos NixOS aqui conforme necessário, por exemplo:
  # ./nixos/secrets.nix     # Segredos via sops-nix
  # ./nixos/wifi.nix        # Redes Wi-Fi pessoais
]
