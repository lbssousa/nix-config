# Módulo de usuários: Esqueleto para definição de usuários
# Os arquivos reais de usuário ficam em users/ e são ignorados pelo git
# Consulte users/skeleton.nix para criar seu arquivo de usuário
{ config, lib, pkgs, ... }:

{
  # Habilitar Zsh globalmente (necessário para usar como shell de usuário)
  programs.zsh.enable = true;
  programs.fish.enable = true;

  # Configuração padrão de sudo
  security.sudo = {
    enable = true;
    wheelNeedsPassword = true;
  };

  # Os usuários reais são definidos em arquivos separados (não commitados)
  # Exemplo: users/joao.nix
  # Para criar um usuário, copie users/skeleton.nix para users/<seu-usuario>.nix
  # e descomente/ajuste as configurações

  # Configuração de grupos padrão disponíveis
  users.groups = {
    plugdev = {};      # Acesso a dispositivos USB
    dialout = {};      # Portas seriais
    video = {};        # Acesso à GPU
    audio = {};        # Acesso ao áudio
    docker = {};       # Compatibilidade com Docker (Podman)
  };
}
