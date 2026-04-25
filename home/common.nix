# Configuração Home Manager base — aplicada a todos os usuários
# Importada automaticamente por cada homeConfiguration no flake.nix.
# Os arquivos por usuário ficam em home/users/<usuario>/home.nix.
{ pkgs, lib, ... }:

{
  home = {
    # Home Manager precisa conhecer o usuário e o diretório home.
    # NOTA: Estes valores são sobrescritos pelo mkHome em flake.nix.
    username = lib.mkDefault "user";
    homeDirectory = lib.mkDefault "/home/user";

    # Versão do Home Manager (não altere sem verificar as release notes)
    stateVersion = "25.05";

    # Extensão de backup para arquivos gerenciados pelo Home Manager
    backupFileExtension = "hm-backup";

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
        # NixOS shortcuts
        nrs = "sudo nixos-rebuild switch --flake /etc/nixos";
        nru = "sudo nix flake update /etc/nixos && sudo nixos-rebuild switch --flake /etc/nixos";
        nrb = "sudo nixos-rebuild boot --flake /etc/nixos";
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
        serverAliveInterval = 60;
        serverAliveCountMax = 3;
      };
    };

    # Permitir que o Home Manager gerencie o ambiente de sessão
    home-manager.enable = true;
  };
}
