# Módulo de shells: Bash, Fish e Zsh (Zsh como padrão)
{ config, lib, pkgs, ... }:

{
  # Instalar as três shells
  environment.systemPackages = with pkgs; [
    bash
    fish
    zsh
    # Utilitários para Zsh
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-history-substring-search
    # Oh My Zsh (gerenciador de plugins/temas)
    oh-my-zsh
    # Starship prompt (cross-shell)
    starship
  ];

  # Habilitar Bash (já é padrão, mas garantimos configuração)
  programs.bash = {
    # Completions extras para Bash
    completion.enable = true;
  };

  # Habilitar Fish shell
  programs.fish = {
    enable = true;
    # Completions adicionais
    vendor = {
      completions.enable = true;
      config.enable = true;
      functions.enable = true;
    };
  };

  # Habilitar Zsh como shell padrão do sistema
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
    # histFile e histSize são configurados por usuário via home-manager (home.nix)
  };

  # Definir Zsh como shell padrão para novos usuários
  users.defaultUserShell = pkgs.zsh;

  # Adicionar shells ao /etc/shells
  environment.shells = with pkgs; [ bash fish zsh ];
}
