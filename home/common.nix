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

    packages = [
      pkgs.run0-sudo
      pkgs.grc # Coloriza a saída de comandos comuns (usado pelo plugin grc do Fish)
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

    # Configuração do Fish shell (shell padrão do sistema)
    fish = {
      enable = true;
      interactiveShellInit = ''
        function _nix_cfg
          set -l entries (ls -A /etc/nixos 2>/dev/null)
          if test (count $entries) -gt 0
            printf '%s' /etc/nixos
          else
            printf '%s' (xdg-user-dir PROJECTS)/lbssousa/nix-config
          end
        end

        function just
          command just --justfile (_nix_cfg)/justfile $argv
        end
      '';
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
        nrs = "run0 --setenv=SSH_AUTH_SOCK=$SSH_AUTH_SOCK nixos-rebuild switch --flake (_nix_cfg)";
        nru = "run0 --setenv=SSH_AUTH_SOCK=$SSH_AUTH_SOCK sh -c \"nix flake update (_nix_cfg) && nixos-rebuild switch --flake (_nix_cfg)\"";
        nrb = "run0 --setenv=SSH_AUTH_SOCK=$SSH_AUTH_SOCK nixos-rebuild boot --flake (_nix_cfg)";
        hmn = "home-manager news";
        # Podman/Docker aliases
        dk = "podman";
        dkc = "podman-compose";
      };

      # Plugins do Fish: exclusivos do abutre (ver home/users/abutre/fish.nix).
      # Os demais usuários usam o Fish sem plugins.
    };

    # Starship — preset oficial "Catppuccin Powerline", paleta Mocha (a mais escura)
    starship = {
      enable = true;
      enableZshIntegration = lib.mkDefault true;
      enableFishIntegration = lib.mkDefault true;
      enableBashIntegration = lib.mkDefault true;
      settings = {
        "$schema" = "https://starship.rs/config-schema.json";
        format = "[](red)$os$username[](bg:peach fg:red)$directory[](bg:yellow fg:peach)$git_branch$git_status[](fg:yellow bg:green)$c$rust$golang$nodejs$bun$php$java$kotlin$haskell$python[](fg:green bg:sapphire)$conda$nix_shell[](fg:sapphire bg:lavender)$time[ ](fg:lavender)$cmd_duration$line_break$character";
        palette = "catppuccin_mocha";
        os = {
          disabled = false;
          style = "bg:red fg:crust";
          symbols = {
            NixOS = "";
            Windows = "";
            Ubuntu = "󰕈";
            SUSE = "";
            Raspbian = "󰐿";
            Mint = "󰣭";
            Macos = "󰀵";
            Manjaro = "";
            Linux = "󰌽";
            Gentoo = "󰣨";
            Fedora = "󰣛";
            Alpine = "";
            Amazon = "";
            Android = "";
            AOSC = "";
            Arch = "󰣇";
            Artix = "󰣇";
            CentOS = "";
            Debian = "󰣚";
            Redhat = "󱄛";
            RedHatEnterprise = "󱄛";
          };
        };
        username = {
          show_always = true;
          style_user = "bg:red fg:crust";
          style_root = "bg:red fg:crust";
          format = "[ $user]($style)";
        };
        directory = {
          style = "bg:peach fg:crust";
          format = "[ $path ]($style)";
          truncation_length = 3;
          truncation_symbol = "…/";
          substitutions = {
            Documents = "󰈙 ";
            Downloads = " ";
            Music = "󰝚 ";
            Pictures = " ";
            Developer = "󰲋 ";
          };
        };
        git_branch = {
          symbol = "";
          style = "bg:yellow";
          format = "[[ $symbol $branch ](fg:crust bg:yellow)]($style)";
        };
        git_status = {
          style = "bg:yellow";
          format = "[[($all_status$ahead_behind )](fg:crust bg:yellow)]($style)";
        };
        nodejs = {
          symbol = "";
          style = "bg:green";
          format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
        };
        bun = {
          symbol = "";
          style = "bg:green";
          format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
        };
        c = {
          symbol = " ";
          style = "bg:green";
          format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
        };
        rust = {
          symbol = "";
          style = "bg:green";
          format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
        };
        golang = {
          symbol = "";
          style = "bg:green";
          format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
        };
        php = {
          symbol = "";
          style = "bg:green";
          format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
        };
        java = {
          symbol = " ";
          style = "bg:green";
          format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
        };
        kotlin = {
          symbol = "";
          style = "bg:green";
          format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
        };
        haskell = {
          symbol = "";
          style = "bg:green";
          format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
        };
        python = {
          symbol = "";
          style = "bg:green";
          format = "[[ $symbol( $version)(\\(#$virtualenv\\)) ](fg:crust bg:green)]($style)";
        };
        docker_context = {
          symbol = "";
          style = "bg:sapphire";
          format = "[[ $symbol( $context) ](fg:crust bg:sapphire)]($style)";
        };
        conda = {
          symbol = "  ";
          style = "fg:crust bg:sapphire";
          format = "[$symbol$environment ]($style)";
          ignore_base = false;
        };
        nix_shell = {
          disabled = false;
          symbol = " ";
          style = "fg:crust bg:sapphire";
          format = "[$symbol$state( \\($name\\)) ]($style)";
          impure_msg = "impure";
          pure_msg = "pure";
          unknown_msg = "desconhecido";
        };
        time = {
          disabled = false;
          time_format = "%R";
          style = "bg:lavender";
          format = "[[  $time ](fg:crust bg:lavender)]($style)";
        };
        line_break = {
          disabled = false;
        };
        character = {
          disabled = false;
          success_symbol = "[❯](bold fg:green)";
          error_symbol = "[❯](bold fg:red)";
          vimcmd_symbol = "[❮](bold fg:green)";
          vimcmd_replace_one_symbol = "[❮](bold fg:lavender)";
          vimcmd_replace_symbol = "[❮](bold fg:lavender)";
          vimcmd_visual_symbol = "[❮](bold fg:yellow)";
        };
        cmd_duration = {
          show_milliseconds = true;
          format = " in $duration ";
          style = "bg:lavender";
          disabled = false;
          show_notifications = true;
          min_time_to_notify = 45000;
        };
        palettes = {
          catppuccin_mocha = {
            rosewater = "#f5e0dc";
            flamingo = "#f2cdcd";
            pink = "#f5c2e7";
            mauve = "#cba6f7";
            red = "#f38ba8";
            maroon = "#eba0ac";
            peach = "#fab387";
            yellow = "#f9e2af";
            green = "#a6e3a1";
            teal = "#94e2d5";
            sky = "#89dceb";
            sapphire = "#74c7ec";
            blue = "#89b4fa";
            lavender = "#b4befe";
            text = "#cdd6f4";
            subtext1 = "#bac2de";
            subtext0 = "#a6adc8";
            overlay2 = "#9399b2";
            overlay1 = "#7f849c";
            overlay0 = "#6c7086";
            surface2 = "#585b70";
            surface1 = "#45475a";
            surface0 = "#313244";
            base = "#1e1e2e";
            mantle = "#181825";
            crust = "#11111b";
          };
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
