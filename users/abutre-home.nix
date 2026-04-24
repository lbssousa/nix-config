# Configurações home-manager específicas para o usuário abutre
{ pkgs, lib, ... }:

{
  # Usar powerlevel10k como tema do Zsh em vez do Starship
  programs.starship.enableZshIntegration = false;

  programs.zsh = {
    plugins = [
      {
        name = "powerlevel10k";
        src = pkgs.zsh-powerlevel10k;
        file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      }
    ];
    initContent = lib.mkMerge [
      # Instant prompt deve ser o primeiro código executado no .zshrc
      (lib.mkBefore ''
        if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
          source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
        fi
      '')
      # Carregar configuração do powerlevel10k ao final
      ''
        [[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
      ''
      # Injetar SSH_AUTH_SOCK do agente SSH do Bitwarden, quando disponível
      ''
        () {
          local _runtime_dir="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
          local _bw_flatpak_sock="$_runtime_dir/app/com.bitwarden.desktop/bitwarden-ssh-agent.sock"
          local _bw_nix_sock="$_runtime_dir/bitwarden-ssh-agent.sock"
          local _bw_other_sock="$HOME/.bitwarden-ssh-agent.sock"
          if [[ -S "$_bw_flatpak_sock" ]]; then
            export SSH_AUTH_SOCK="$_bw_flatpak_sock"
          elif [[ -S "$_bw_nix_sock" ]]; then
            export SSH_AUTH_SOCK="$_bw_nix_sock"
          elif [[ -S "$_bw_other_sock" ]]; then
            export SSH_AUTH_SOCK="$_bw_other_sock"
          fi
        }
      ''
    ];
  };

  programs.git = {
    userName = "abutre";
    userEmail = "git@example.com";
    signing = {
      # O prefixo key:: é necessário para indicar que é uma chave inline (não um caminho de arquivo)
      key = "key::ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILc5RYDDiqlYAyO7xuDJPLFtx5cMEyN2io/qVsmv55N9 GitHub";
      signByDefault = true;
    };
    extraConfig = {
      gpg.format = "ssh";
      gpg.ssh.program = "/run/current-system/sw/bin/ssh-keygen";
      tag.gpgsign = true;
    };
  };
}
