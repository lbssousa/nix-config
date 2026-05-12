# Configuração Home Manager base — compartilhada por todos os usuários
# no modo standalone do Home Manager.
# Os arquivos por usuário ficam em home/users/<usuario>/home.nix.
{ pkgs, lib, ... }:

{
  imports = [
    ../modules/home/apps/browsers/google-chrome.nix
    ../modules/home/apps/browsers/firefox.nix
    ../modules/home/desktop/ibus-compose.nix
  ];

  home = {
    stateVersion = "26.05";

    # Pacotes instalados para o usuário
    packages = with pkgs; [
      # Ferramentas de desenvolvimento
      gh # GitHub CLI
      glab # GitLab CLI
      # Utilitários modernos
      bat # cat com syntax highlighting
      eza # ls moderno (substituto do exa)
      fd # find moderno
      ripgrep # grep moderno
      fzf # Fuzzy finder
      zoxide # cd inteligente
      # Compressão
      unzip
      zip
      # Monitoramento
      htop
      btop
    ];

    # Variáveis de ambiente do usuário
    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      BROWSER = "xdg-open";
      QT_QPA_PLATFORM = "wayland"; # Forçar backend Wayland para aplicações Qt
    };

  };

  programs = {
    # Git - configuração básica (sobrescreva no arquivo do usuário)
    git = {
      enable = true;
      settings = {
        init.defaultBranch = "main";
        pull.rebase = true;
        rebase.autostash = true;
        core.editor = "nvim";
      };
    };

    # Configuração do Zsh
    zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;

      history = {
        size = 10000;
        save = 50000;
        ignoreDups = true;
        share = true;
      };

      shellAliases = {
        # Substitutos modernos
        ls = "eza";
        ll = "eza -la";
        lt = "eza --tree";
        cat = "bat";
        grep = "rg";
        find = "fd";
        cd = "z"; # zoxide
        # Git shortcuts
        g = "git";
        gs = "git status";
        ga = "git add";
        gc = "git commit";
        gp = "git push";
        gl = "git pull";
        # NixOS shortcuts (run0: eleva via polkit/YubiKey sem setuid;
        # --setenv=SSH_AUTH_SOCK repassa o socket do agente SSH para que
        # nixos-rebuild acesse entradas de flake SSH, ex.: nix-secrets)
        nrs = "run0 --setenv=SSH_AUTH_SOCK=$SSH_AUTH_SOCK nixos-rebuild switch --flake /etc/nixos";
        nru = "run0 --setenv=SSH_AUTH_SOCK=$SSH_AUTH_SOCK sh -c \"nix flake update /etc/nixos && nixos-rebuild switch --flake /etc/nixos\"";
        nrb = "run0 --setenv=SSH_AUTH_SOCK=$SSH_AUTH_SOCK nixos-rebuild boot --flake /etc/nixos";
        hms = "home-manager switch --flake /etc/nixos#$(whoami)@$(hostname)";
        # Podman/Docker aliases
        dk = "podman";
        dkc = "podman-compose";
      };

      initContent = ''
        # Zoxide (cd inteligente)
        eval "$(zoxide init zsh)"

        # fzf integração
        source ${pkgs.fzf}/share/fzf/key-bindings.zsh
        source ${pkgs.fzf}/share/fzf/completion.zsh

        # Completions case-insensitive
        zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

      '';
    };

    # Configuração do Fish shell
    fish = {
      enable = true;
      interactiveShellInit = ''
        # Zoxide
        zoxide init fish | source

        # Starship prompt
        starship init fish | source
      '';
      shellAliases = {
        ls = "eza";
        ll = "eza -la";
        cat = "bat";
        grep = "rg";
        find = "fd";
      };
    };

    # Starship - prompt cross-shell moderno
    starship = {
      enable = true;
      enableZshIntegration = lib.mkDefault true;
      enableFishIntegration = lib.mkDefault true;
      enableBashIntegration = lib.mkDefault true;
      settings = {
        add_newline = true;
        character = {
          success_symbol = "[❯](bold green)";
          error_symbol = "[❯](bold red)";
        };
        directory = {
          truncation_length = 3;
          truncate_to_repo = true;
          style = "bold cyan";
        };
        git_branch = {
          symbol = " ";
          style = "bold purple";
        };
        nix_shell = {
          symbol = "❄️ ";
          style = "bold blue";
        };
      };
    };

    # Zoxide - cd inteligente
    zoxide = {
      enable = true;
      enableZshIntegration = lib.mkDefault true;
      enableFishIntegration = lib.mkDefault true;
      enableBashIntegration = lib.mkDefault true;
    };

    # fzf - fuzzy finder
    fzf = {
      enable = true;
      enableZshIntegration = lib.mkDefault true;
      enableFishIntegration = lib.mkDefault true;
      enableBashIntegration = lib.mkDefault true;
    };

    # Configuração do Neovim básica
    neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
      withRuby = false;
      withPython3 = false;
      extraConfig = ''
        set number
        set relativenumber
        set expandtab
        set tabstop=2
        set shiftwidth=2
        set smartindent
        set termguicolors
        set clipboard=unnamedplus
      '';
    };

    # Configuração do SSH do usuário
    ssh = {
      enable = true;
      # Desabilita os valores padrão obsoletos; os valores desejados são
      # definidos explicitamente em matchBlocks abaixo
      enableDefaultConfig = false;
      matchBlocks."*" = {
        addKeysToAgent = "yes";
        controlMaster = "auto";
        controlPersist = "10m";
        controlPath = "~/.ssh/cm-%r@%h:%p";
        serverAliveInterval = 60;
        serverAliveCountMax = 3;
      };
    };
  };
}
