# Base Home Manager configuration — shared by all users.
# Applied as a NixOS module via home-manager.users (dendritic/flake/home-nixos-module.nix).
# Per-user customizations live in home/users/<user>/home.nix.
{ pkgs, lib, ... }:

{
  imports = [
    ../modules/home/apps/security/bitwarden.nix
  ];

  # Zathura as the default PDF viewer.
  # Users with gnome.nix can override it with Papers (plain > mkDefault).
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
      pkgs.grc # Colorizes the output of common commands (used by the Fish grc plugin)
    ];

    # User environment variables
    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      BROWSER = "xdg-open";
      QT_QPA_PLATFORM = "wayland"; # Force the Wayland backend for Qt applications
    };

  };

  programs = {
    bash = {
      enable = true;
      historyControl = [ "ignoredups" ];
      shellAliases = {
        # Modern replacements
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
        # NixOS shortcuts (run0: elevates via polkit/YubiKey without setuid;
        # --setenv=SSH_AUTH_SOCK passes the SSH agent socket through so
        # nixos-rebuild can access SSH-gated flake inputs, e.g. nix-secrets)
        # Home Manager is a NixOS module — nrs/nrb apply HM automatically.
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

    # Git - basic configuration (override in the user's file)
    git = {
      enable = true;
      settings = {
        init.defaultBranch = "main";
        pull.rebase = true;
        rebase.autostash = true;
        core.editor = "nvim";
      };
    };

    # Zsh configuration
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
        # Modern replacements
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
        # NixOS shortcuts (run0: elevates via polkit/YubiKey without setuid;
        # --setenv=SSH_AUTH_SOCK passes the SSH agent socket through so
        # nixos-rebuild can access SSH-gated flake inputs, e.g. nix-secrets)
        # Home Manager is a NixOS module — nrs/nrb apply HM automatically.
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

        # Zoxide (smart cd)
        eval "$(zoxide init zsh)"

        # fzf integration
        source ${pkgs.fzf}/share/fzf/key-bindings.zsh
        source ${pkgs.fzf}/share/fzf/completion.zsh

        # Case-insensitive completions
        zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

        just() { command just --justfile "$(_nix_cfg)/justfile" "$@"; }
      '';
    };

    # Fish shell configuration (the system's default shell)
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
        # Modern replacements
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
        # NixOS shortcuts (run0: elevates via polkit/YubiKey without setuid;
        # --setenv=SSH_AUTH_SOCK passes the SSH agent socket through so
        # nixos-rebuild can access SSH-gated flake inputs, e.g. nix-secrets)
        # Home Manager is a NixOS module — nrs/nrb apply HM automatically.
        nrs = "run0 --setenv=SSH_AUTH_SOCK=$SSH_AUTH_SOCK nixos-rebuild switch --flake (_nix_cfg)";
        nru = "run0 --setenv=SSH_AUTH_SOCK=$SSH_AUTH_SOCK sh -c \"nix flake update (_nix_cfg) && nixos-rebuild switch --flake (_nix_cfg)\"";
        nrb = "run0 --setenv=SSH_AUTH_SOCK=$SSH_AUTH_SOCK nixos-rebuild boot --flake (_nix_cfg)";
        hmn = "home-manager news";
        # Podman/Docker aliases
        dk = "podman";
        dkc = "podman-compose";
      };

      # Fish plugins: exclusive to abutre (see home/users/abutre/fish.nix).
      # Other users use Fish without plugins.
    };

    # Starship — official "Catppuccin Powerline" preset, Mocha palette (the darkest)
    starship = {
      enable = true;
      enableZshIntegration = lib.mkDefault true;
      enableFishIntegration = lib.mkDefault true;
      enableBashIntegration = lib.mkDefault true;
      settings = {
        "$schema" = "https://starship.rs/config-schema.json";
        format = "[](red)$os$username[](bg:peach fg:red)$directory[](bg:yellow fg:peach)$git_branch$git_status[](fg:yellow bg:green)$c$rust$golang$nodejs$bun$php$java$kotlin$haskell$python[](fg:green bg:sapphire)$conda$nix_shell[](fg:sapphire bg:lavender)$time[ ](fg:lavender)$cmd_duration$line_break$character";
        palette = "catppuccin_mocha";
        os = {
          disabled = false;
          style = "bg:red fg:crust";
          symbols = {
            NixOS = "";
            Windows = "";
            Ubuntu = "󰕈";
            SUSE = "";
            Raspbian = "󰐿";
            Mint = "󰣭";
            Macos = "󰀵";
            Manjaro = "";
            Linux = "󰌽";
            Gentoo = "󰣨";
            Fedora = "󰣛";
            Alpine = "";
            Amazon = "";
            Android = "";
            AOSC = "";
            Arch = "󰣇";
            Artix = "󰣇";
            CentOS = "";
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
            Downloads = " ";
            Music = "󰝚 ";
            Pictures = " ";
            Developer = "󰲋 ";
          };
        };
        git_branch = {
          symbol = "";
          style = "bg:yellow";
          format = "[[ $symbol $branch ](fg:crust bg:yellow)]($style)";
        };
        git_status = {
          style = "bg:yellow";
          format = "[[($all_status$ahead_behind )](fg:crust bg:yellow)]($style)";
        };
        nodejs = {
          symbol = "";
          style = "bg:green";
          format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
        };
        bun = {
          symbol = "";
          style = "bg:green";
          format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
        };
        c = {
          symbol = " ";
          style = "bg:green";
          format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
        };
        rust = {
          symbol = "";
          style = "bg:green";
          format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
        };
        golang = {
          symbol = "";
          style = "bg:green";
          format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
        };
        php = {
          symbol = "";
          style = "bg:green";
          format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
        };
        java = {
          symbol = " ";
          style = "bg:green";
          format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
        };
        kotlin = {
          symbol = "";
          style = "bg:green";
          format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
        };
        haskell = {
          symbol = "";
          style = "bg:green";
          format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
        };
        python = {
          symbol = "";
          style = "bg:green";
          format = "[[ $symbol( $version)(\\(#$virtualenv\\)) ](fg:crust bg:green)]($style)";
        };
        docker_context = {
          symbol = "";
          style = "bg:sapphire";
          format = "[[ $symbol( $context) ](fg:crust bg:sapphire)]($style)";
        };
        conda = {
          symbol = "  ";
          style = "fg:crust bg:sapphire";
          format = "[$symbol$environment ]($style)";
          ignore_base = false;
        };
        nix_shell = {
          disabled = false;
          symbol = " ";
          style = "fg:crust bg:sapphire";
          format = "[$symbol$state( \\($name\\)) ]($style)";
          impure_msg = "impure";
          pure_msg = "pure";
          unknown_msg = "unknown";
        };
        time = {
          disabled = false;
          time_format = "%R";
          style = "bg:lavender";
          format = "[[  $time ](fg:crust bg:lavender)]($style)";
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
          format = " in $duration ";
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

    # Zoxide - smart cd
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

    # Themed icons for the default XDG directories in Portuguese
    # (system locale is pt_BR — see modules/system/core/localization.nix; these
    # are the literal on-disk folder names, e.g. ~/Documentos, ~/Imagens, so
    # the keys below must stay in Portuguese for eza to match them. English
    # names already have native icons in eza.)
    eza = {
      enable = true;
      icons = "auto";
      theme.filenames = {
        # pt_BR
        "Área de trabalho" = {
          icon = {
            glyph = "";
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
            glyph = "";
          };
        };
        "Modelos" = {
          icon = {
            glyph = "";
          };
        };
        "Público" = {
          icon = {
            glyph = "";
          };
        };
        "Projetos" = {
          icon = {
            glyph = "";
          };
        };
        # pt (European Portuguese)
        "Área de Trabalho" = {
          icon = {
            glyph = "";
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
            glyph = "";
          };
        };
      };
    };

    # Basic Neovim configuration (default for all users)
    # Users who import modules/home/apps/editors/nvf/ override this
    # declarative configuration.
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

    # User SSH configuration
    ssh = {
      enable = true;
      # Disables the deprecated defaults; the desired values are set
      # explicitly in settings below
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
