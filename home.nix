# Configuração Home Manager base
# Utilizado como ponto de partida para configurações de usuário
# Os usuários reais devem criar seu próprio arquivo em users/<usuario>.nix
# e referenciar este arquivo ou criar o próprio home.nix customizado
{ config, pkgs, lib, ... }:

{
  # Home Manager precisa conhecer o usuário e o diretório home
  # NOTA: Estes valores devem ser sobrescritos pelo arquivo do usuário real
  home.username = lib.mkDefault "user";
  home.homeDirectory = lib.mkDefault "/home/user";

  # Versão do Home Manager (não altere sem verificar as release notes)
  home.stateVersion = "25.05";

  # Pacotes instalados para o usuário
  home.packages = with pkgs; [
    # Ferramentas de desenvolvimento
    gh          # GitHub CLI
    glab        # GitLab CLI
    # Utilitários modernos
    bat         # cat com syntax highlighting
    eza         # ls moderno (substituto do exa)
    fd          # find moderno
    ripgrep     # grep moderno
    fzf         # Fuzzy finder
    zoxide      # cd inteligente
    # Compressão
    unzip
    zip
    # Monitoramento
    htop
    btop
  ];

  # Variáveis de ambiente do usuário
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    BROWSER = "brave";
  };

  # Adicionar diretórios ao PATH do usuário
  home.sessionPath = [
    "$HOME/.linuxbrew/bin"       # Homebrew do usuário (se instalado)
    "/home/linuxbrew/.linuxbrew/bin"  # Homebrew system-wide (se instalado)
  ];

  # Git - configuração básica (sobrescreva no arquivo do usuário)
  programs.git = {
    enable = true;
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
      rebase.autostash = true;
      core.editor = "nvim";
    };
  };

  # Configuração do Zsh
  programs.zsh = {
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
      hms = "home-manager switch --flake /etc/nixos";
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

      # Homebrew path
      if [ -d "/home/linuxbrew/.linuxbrew" ]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
      fi
    '';
  };

  # Configuração do Fish shell
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      # Zoxide
      zoxide init fish | source

      # Homebrew
      if test -d /home/linuxbrew/.linuxbrew
        eval (/home/linuxbrew/.linuxbrew/bin/brew shellenv)
      end

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
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
    enableBashIntegration = true;
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
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
    enableBashIntegration = true;
  };

  # fzf - fuzzy finder
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
    enableBashIntegration = true;
  };

  # Configuração do Neovim básica
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
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
  programs.ssh = {
    enable = true;
    addKeysToAgent = "yes";
    extraConfig = ''
      ServerAliveInterval 60
      ServerAliveCountMax 3
    '';
  };

  # Permitir que o Home Manager gerencie o ambiente de sessão
  programs.home-manager.enable = true;
}
