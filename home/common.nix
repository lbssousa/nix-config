# Configuração Home Manager base — compartilhada por todos os usuários.
# Aplicada como módulo NixOS via home-manager.users (dendritic/flake/home-nixos-module.nix).
# As customizações por usuário ficam em home/users/<usuario>/home.nix.
{ pkgs, lib, ... }:

{
  imports = [
    ../modules/home/apps/security/bitwarden.nix
  ];

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

    packages = [ pkgs.run0-sudo ];

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
        # Home Manager é módulo NixOS — nrs/nrb aplicam HM automaticamente.
        nrs = "run0 --setenv=SSH_AUTH_SOCK=$SSH_AUTH_SOCK nixos-rebuild switch --flake $(_nix_cfg)";
        nru = "run0 --setenv=SSH_AUTH_SOCK=$SSH_AUTH_SOCK sh -c \"nix flake update $(_nix_cfg) && nixos-rebuild switch --flake $(_nix_cfg)\"";
        nrb = "run0 --setenv=SSH_AUTH_SOCK=$SSH_AUTH_SOCK nixos-rebuild boot --flake $(_nix_cfg)";
        hmn = "home-manager news";
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
        # Home Manager é módulo NixOS — nrs/nrb aplicam HM automaticamente.
        nrs = "run0 --setenv=SSH_AUTH_SOCK=$SSH_AUTH_SOCK nixos-rebuild switch --flake $(_nix_cfg)";
        nru = "run0 --setenv=SSH_AUTH_SOCK=$SSH_AUTH_SOCK sh -c \"nix flake update $(_nix_cfg) && nixos-rebuild switch --flake $(_nix_cfg)\"";
        nrb = "run0 --setenv=SSH_AUTH_SOCK=$SSH_AUTH_SOCK nixos-rebuild boot --flake $(_nix_cfg)";
        hmn = "home-manager news";
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

    # Starship — prompt estilo Powerlevel10k lean, duas linhas, conciso
    starship = {
      enable = true;
      enableZshIntegration = lib.mkDefault true;
      enableFishIntegration = lib.mkDefault true;
      enableBashIntegration = lib.mkDefault true;
      settings = {
        "$schema" = "https://starship.rs/config-schema.json";

        # Linha 1 esquerda: OS · usuário@host (só SSH/root) · dir · git · versões · contextos
        # Linha 1 direita: duração · hora
        # Linha 2: ❯
        format = "$os$username$hostname$directory$git_branch$git_status$c$cpp$rust$golang$nodejs$bun$php$java$kotlin$haskell$python$docker_context$nix_shell$conda$pixi$line_break$character";
        right_format = "$cmd_duration$time";

        add_newline = true;
        palette = "lean";

        palettes.lean = {
          p_blue   = "#61afef";
          p_green  = "#98c379";
          p_yellow = "#e5c07b";
          p_red    = "#e06c75";
          p_cyan   = "#56b6c2";
          p_purple = "#c678dd";
          p_orange = "#d19a66";
          p_grey   = "#5c6370";
          p_fg     = "#abb2bf";
        };

        os = {
          disabled = false;
          style = "bold fg:p_blue";
          format = "[$symbol ]($style)";
          symbols = {
            NixOS       = "";
            Linux       = "󰌽";
            Windows     = "󰍲";
            Macos       = "󰀵";
            Ubuntu      = "󰕈";
            Debian      = "󰣚";
            Fedora      = "󰣛";
            Arch        = "󰣇";
            Artix       = "󰣇";
            Gentoo      = "󰣨";
            Alpine      = "";
            Manjaro     = "";
            Mint        = "󰣭";
            Pop         = "";
            EndeavourOS = "";
            CentOS      = "";
            Raspbian    = "󰐿";
            SUSE        = "";
            Amazon      = "";
            Android     = "";
            AOSC        = "";
            Redhat      = "󱄛";
            RedHatEnterprise = "󱄛";
          };
        };

        username = {
          show_always = false;
          style_user = "fg:p_fg";
          style_root = "bold fg:p_red";
          format = "[$user]($style)";
        };

        hostname = {
          ssh_only = true;
          style = "fg:p_fg";
          format = "[@$hostname ]($style)";
        };

        directory = {
          style = "bold fg:p_blue";
          read_only = " 󰌾";
          read_only_style = "fg:p_red";
          format = "[ $path]($style)[$read_only]($read_only_style) ";
          truncation_length = 4;
          truncation_symbol = "…/";
          substitutions = {
            "Documents"  = "󰈙 ";
            "Downloads"  = "󰇚 ";
            "Music"      = "󰝚 ";
            "Pictures"   = "󰉏 ";
            "Videos"     = "󰕧 ";
            "Desktop"    = "󰇄 ";
            "Projects"   = "󰲋 ";
            "Projetos"   = "󰲋 ";
            "~"          = "~ ";
          };
        };

        git_branch = {
          symbol = " ";
          style = "fg:p_green";
          format = "[$symbol$branch(:$remote_branch)]($style) ";
          truncation_length = 24;
          truncation_symbol = "…";
        };

        git_status = {
          style = "fg:p_yellow";
          format = "([\\[$all_status$ahead_behind\\]]($style) )";
          conflicted  = "󰩌 ";
          untracked   = "?";
          modified    = "!";
          staged      = "+";
          renamed     = "»";
          deleted     = "✘";
          stashed     = "󰏗 ";
          ahead       = "⇡$\{count}";
          behind      = "⇣$\{count}";
          diverged    = "⇡$\{ahead_count}⇣$\{behind_count}";
        };

        # Linguagens — ícone + versão, aparecem só quando relevante
        nodejs   = { symbol = " "; style = "fg:p_green";  format = "[$symbol($version) ]($style)"; };
        bun      = { symbol = " "; style = "fg:p_yellow"; format = "[$symbol($version) ]($style)"; };
        rust     = { symbol = " "; style = "fg:p_orange"; format = "[$symbol($version) ]($style)"; };
        golang   = { symbol = " "; style = "fg:p_cyan";   format = "[$symbol($version) ]($style)"; };
        python   = { symbol = " "; style = "fg:p_yellow"; format = "[$symbol($version)( $virtualenv) ]($style)"; };
        java     = { symbol = " "; style = "fg:p_orange"; format = "[$symbol($version) ]($style)"; };
        kotlin   = { symbol = " "; style = "fg:p_purple"; format = "[$symbol($version) ]($style)"; };
        haskell  = { symbol = " "; style = "fg:p_purple"; format = "[$symbol($version) ]($style)"; };
        php      = { symbol = " "; style = "fg:p_purple"; format = "[$symbol($version) ]($style)"; };
        c        = { symbol = " "; style = "fg:p_blue";   format = "[$symbol($version) ]($style)"; };
        cpp      = { symbol = " "; style = "fg:p_blue";   format = "[$symbol($version) ]($style)"; };

        # Contextos de ambiente
        docker_context = {
          symbol = " ";
          style = "fg:p_blue";
          format = "[$symbol$context ]($style)";
          only_with_files = true;
        };

        nix_shell = {
          disabled = false;
          symbol = " ";
          style = "fg:p_blue";
          format = "[$symbol$state( \\($name\\)) ]($style)";
          impure_msg = "impure";
          pure_msg   = "pure";
        };

        conda = {
          symbol = "󰌠 ";
          style = "fg:p_green";
          format = "[$symbol$environment ]($style)";
          ignore_base = true;
        };

        pixi = {
          symbol = "󰏓 ";
          style = "fg:p_green";
          format = "[$symbol$environment ]($style)";
        };

        # Lado direito: duração e hora
        cmd_duration = {
          min_time = 2000;
          style = "fg:p_yellow";
          format = "[ 󱎫 $duration ]($style)";
        };

        time = {
          disabled = false;
          time_format = "%H:%M";
          style = "fg:p_grey";
          format = "[󰥔 $time ]($style)";
        };

        line_break.disabled = false;

        character = {
          disabled = false;
          success_symbol         = "[❯](bold fg:p_green)";
          error_symbol           = "[❯](bold fg:p_red)";
          vimcmd_symbol          = "[❮](bold fg:p_green)";
          vimcmd_replace_one_symbol = "[❮](bold fg:p_purple)";
          vimcmd_replace_symbol  = "[❮](bold fg:p_purple)";
          vimcmd_visual_symbol   = "[❮](bold fg:p_yellow)";
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
