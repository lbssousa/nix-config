# Configurações home-manager específicas para o usuário abutre
{ pkgs, lib, ... }:

{
  programs = {
    # Usar powerlevel10k como tema do Zsh em vez do Starship
    starship.enableZshIntegration = false;

    zsh = {
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
          if [[ -S "$HOME/.var/app/com.bitwarden.desktop/data/.bitwarden-ssh-agent.sock" ]]; then
            export SSH_AUTH_SOCK="$HOME/.var/app/com.bitwarden.desktop/data/.bitwarden-ssh-agent.sock"
          elif [[ -S "$HOME/.bitwarden-ssh-agent.sock" ]]; then
            export SSH_AUTH_SOCK="$HOME/.bitwarden-ssh-agent.sock"
          fi
        ''
      ];
    };

    git = {
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
  };
}
