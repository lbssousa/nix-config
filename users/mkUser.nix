# Função auxiliar para criar definições de usuário NixOS
# Uso: import ./mkUser.nix { inherit pkgs lib; } { username = ...; ... }
#
# NOTA: A configuração do Home Manager é gerida separadamente via homeConfigurations
# no flake.nix. Consulte home/users/<usuario>/home.nix para customizações por usuário.
#
# NOTA: O nome completo (description) é definido via outputs do flake nix-secrets
# (inputs.nix-secrets.${username}.fullName). Não deve ser definido aqui.
{ pkgs, lib }:
{
  username,
  # UID numérico fixo. SEMPRE defina para evitar reatribuição após adicionar/remover
  # usuários, o que causaria incompatibilidade de propriedade nos arquivos do $HOME.
  uid ? null,
  # Define se o usuário pertence ao grupo "wheel" (sudo). Padrão: false.
  hasSudo ? false,
}:

{
  # Cria um grupo com o mesmo nome do usuário (necessário para aplicativos que
  # chamam `chown username:username`, como o epson-printer-utility).
  users.groups.${username} = { };

  users.users.${username} = {
    isNormalUser = true;
  }
  // lib.optionalAttrs (uid != null) { inherit uid; }
  // {
    # Grupos essenciais para desktop com GNOME + containers
    extraGroups = [
      "networkmanager" # Gerenciar conexões de rede
      "video" # Acesso à GPU
      "audio" # Acesso ao áudio
      "plugdev" # Acesso a dispositivos USB
      "dialout" # Portas seriais
      "docker" # Compatibilidade com Docker (Podman)
    ]
    ++ lib.optionals hasSudo [
      "wheel" # sudo
    ];
    shell = pkgs.bash; # Shell padrão (Bash)
    # Senha inicial: o usuário será solicitado a trocá-la no primeiro login.
    # Se uma senha personalizada for definida durante a instalação (ver INSTALLATION.md),
    # a troca não será exigida.
    initialPassword = "nixos";
  };
}
