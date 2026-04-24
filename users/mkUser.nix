# Função auxiliar para criar definições de usuário NixOS
# Uso: import ./mkUser.nix { inherit pkgs lib; } { username = ...; description = ...; ... }
{ pkgs, lib }:
{
  username,
  description,
  # Define se o usuário pertence ao grupo "wheel" (sudo). Padrão: false.
  hasSudo ? false,
  # Módulos Home Manager adicionais para importar além de ../home.nix. Padrão: [].
  extraHomeImports ? [ ],
}:

{
  users.users.${username} = {
    isNormalUser = true;
    inherit description;
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
    shell = pkgs.zsh; # Shell padrão (Zsh)
    # Senha inicial: o usuário será solicitado a trocá-la no primeiro login.
    # Se uma senha personalizada for definida durante a instalação (ver INSTALLATION.md),
    # a troca não será exigida.
    initialPassword = "nixos";
  };

  # Configuração Home Manager para este usuário
  home-manager.users.${username} = {
    imports = [ ../home.nix ] ++ extraHomeImports;
  };
}
