# Configuração Home Manager base — compartilhada por todos os usuários
# no modo standalone do Home Manager.
# Os arquivos por usuário ficam em home/users/<usuario>/home.nix.
{ pkgs, lib, ... }:

{
  # Zathura como visualizador de PDF padrão.
  # Usuários com gnome.nix podem sobrescrever com Papers (plain > mkDefault).
  xdg.mimeApps.defaultApplications = {
    "application/pdf" = lib.mkDefault "org.pwmt.zathura.desktop";
    "application/x-bzpdf" = lib.mkDefault "org.pwmt.zathura.desktop";
    "application/x-gzpdf" = lib.mkDefault "org.pwmt.zathura.desktop";
    "application/x-xzpdf" = lib.mkDefault "org.pwmt.zathura.desktop";
    "application/x-ext-pdf" = lib.mkDefault "org.pwmt.zathura.desktop";
  };

  home = {
    stateVersion = "26.05";

    # Variáveis de ambiente do usuário
    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      BROWSER = "xdg-open";
      QT_QPA_PLATFORM = "wayland"; # Forçar backend Wayland para aplicações Qt
    };

  };

  programs = {
    bash = {
      enable = true;
      historyControl = [ "ignoredups" ];
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
        nrs = "run0 --setenv=SSH_AUTH_SOCK=$SSH_AUTH_SOCK nixos-rebuild switch --flake $(_nix_cfg)";
        nru = "run0 --setenv=SSH_AUTH_SOCK=$SSH_AUTH_SOCK sh -c \"nix flake update $(_nix_cfg) && nixos-rebuild switch --flake $(_nix_cfg)\"";
        nrb = "run0 --setenv=SSH_AUTH_SOCK=$SSH_AUTH_SOCK nixos-rebuild boot --flake $(_nix_cfg)";
        hms = "home-manager switch --flake $(_nix_cfg)#$(whoami)@$(hostname)";
        hmn = "home-manager news --flake $(_nix_cfg)#$(whoami)@$(hostname)";
        # Podman/Docker aliases
        dk = "podman";
        dkc = "podman-compose";
      };
      initExtra = ''
        _nix_cfg() {
          if [ -n "$(ls -A /etc/nixos 2>/dev/null)" ]; then
            printf '%s' /etc/nixos
          else
            printf '%s' "$(xdg-user-dir PROJECTS)/lbssousa/nix-config"
          fi
        }
        bind 'set completion-ignore-case on'
        just() { command just --justfile "$(_nix_cfg)/justfile" "$@"; }
      '';
    };

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
        nrs = "run0 --setenv=SSH_AUTH_SOCK=$SSH_AUTH_SOCK nixos-rebuild switch --flake $(_nix_cfg)";
        nru = "run0 --setenv=SSH_AUTH_SOCK=$SSH_AUTH_SOCK sh -c \"nix flake update $(_nix_cfg) && nixos-rebuild switch --flake $(_nix_cfg)\"";
        nrb = "run0 --setenv=SSH_AUTH_SOCK=$SSH_AUTH_SOCK nixos-rebuild boot --flake $(_nix_cfg)";
        hms = "home-manager switch --flake $(_nix_cfg)#$(whoami)@$(hostname)";
        hmn = "home-manager news --flake $(_nix_cfg)#$(whoami)@$(hostname)";
        # Podman/Docker aliases
        dk = "podman";
        dkc = "podman-compose";
      };

      initContent = ''
        _nix_cfg() {
          if [ -n "$(ls -A /etc/nixos 2>/dev/null)" ]; then
            printf '%s' /etc/nixos
          else
            printf '%s' "$(xdg-user-dir PROJECTS)/lbssousa/nix-config"
          fi
        }

        # Zoxide (cd inteligente)
        eval "$(zoxide init zsh)"

        # fzf integração
        source ${pkgs.fzf}/share/fzf/key-bindings.zsh
        source ${pkgs.fzf}/share/fzf/completion.zsh

        # Completions case-insensitive
        zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

        just() { command just --justfile "$(_nix_cfg)/justfile" "$@"; }
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

    # Ícones temáticos para diretórios padrão XDG em português
    # (os nomes em inglês já têm ícones nativos no eza)
    eza = {
      enable = true;
      icons = "auto";
      theme.filenames = {
        # pt_BR
        "Área de trabalho" = {
          icon = {
            glyph = "";
          };
        };
        "Documentos" = {
          icon = {
            glyph = "󰲂";
          };
        };
        "Músicas" = {
          icon = {
            glyph = "󱍙";
          };
        };
        "Imagens" = {
          icon = {
            glyph = "󰉏";
          };
        };
        "Vídeos" = {
          icon = {
            glyph = "";
          };
        };
        "Modelos" = {
          icon = {
            glyph = "";
          };
        };
        "Público" = {
          icon = {
            glyph = "";
          };
        };
        "Projetos" = {
          icon = {
            glyph = "";
          };
        };
        # pt (português europeu)
        "Área de Trabalho" = {
          icon = {
            glyph = "";
          };
        };
        "Transferências" = {
          icon = {
            glyph = "󰉍";
          };
        };
        "Música" = {
          icon = {
            glyph = "󱍙";
          };
        };
        "Projectos" = {
          icon = {
            glyph = "";
          };
        };
      };
    };

    # Configuração do Neovim básica (padrão para todos os usuários)
    # Usuários que importam modules/home/apps/editors/nvf/ substituem esta
    # configuração declarativa.
    neovim = {
      enable = lib.mkDefault true;
      defaultEditor = lib.mkDefault true;
      viAlias = lib.mkDefault true;
      vimAlias = lib.mkDefault true;
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
      # definidos explicitamente em settings abaixo
      enableDefaultConfig = false;
      settings = {
        "*" = {
          AddKeysToAgent = "yes";
          ControlMaster = "auto";
          ControlPersist = "10m";
          ControlPath = "~/.ssh/cm-%r@%h:%p";
          ServerAliveInterval = 60;
          ServerAliveCountMax = 3;
        };
      };
    };
  };
}
