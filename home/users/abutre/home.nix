# Configurações Home Manager específicas para o usuário abutre
{
  config,
  pkgs,
  lib,
  desktop ? "gnome",
  ...
}:

let
  isPlasma = desktop == "plasma";
  isGnome = desktop == "gnome";
in

{
  imports = [
    ../../modules/apps/nix-validation.nix
    ../../modules/apps/security/yubikey.nix
  ];

  home = {
    username = lib.mkDefault abutre;
    homeDirectory = lib.mkDefault "/home/abutre";
    packages =
      [ pkgs.github-copilot-cli ]
      ++ lib.optionals isPlasma [ pkgs.kdePackages.yakuake ]
      ++ lib.optionals isGnome [
        pkgs.gnomeExtensions.ddterm
      ];
    # Cursor padrão do GNOME — configura Wayland, XWayland e o link ~/.icons/default
    pointerCursor = lib.mkIf isGnome {
      package = pkgs.adwaita-icon-theme;
      name = "Adwaita";
      size = 24;
      gtk.enable = true;
    };

  };

  xdg.configFile = lib.optionalAttrs isPlasma {
    "autostart/yakuake.desktop".text = ''
      [Desktop Entry]
      Exec=yakuake
      Icon=yakuake
      Name=Yakuake
      Type=Application
      X-KDE-StartupNotify=false
    '';

    "konsolerc".text = ''
      [Desktop Entry]
      DefaultProfile=default.profile
    '';

    "yakuakerc".text = ''
      [Dialogs]
      FirstRun=false

      [Window]
      Height=90
      KeepOpen=false
      ShowOnStart=false
      Width=90
    '';
  };

  xdg.dataFile = lib.optionalAttrs isPlasma {
    "konsole/default.profile".text = ''
      [Appearance]
      Font=JetBrainsMono Nerd Font Mono,14,-1,5,50,0,0,0,0,0

      [General]
      Name=Default
      Parent=FALLBACK/
      TerminalColumns=154
      TerminalRows=32
    '';
  };

  # Garante que sobras do Yakuake sejam removidas ao trocar para ambiente não-Plasma.
  home.activation.cleanupYakuakeWhenNotPlasma = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ "${desktop}" != "plasma" ]; then
      rm -f "${config.xdg.configHome}/autostart/yakuake.desktop"
      rm -f "${config.xdg.configHome}/konsolerc"
      rm -f "${config.xdg.configHome}/yakuakerc"
    fi
  '';

  dconf.settings = lib.mkIf isGnome {
    # IBus em Wayland puro: delega layout ao sistema (evita setxkbmap) e
    # carrega a engine BR na inicialização da sessão.
    "desktop/ibus/general" = {
      use-system-keyboard-layout = true;
      preload-engines = [ "xkb:br::por" ];
    };

    "org/gnome/desktop/input-sources" = {
      sources = [ (lib.hm.gvariant.mkTuple [ "xkb" "br" ]) ];
      mru-sources = [ (lib.hm.gvariant.mkTuple [ "xkb" "br" ]) ];
      xkb-model = "abnt2";
    };

    # Terminal (Ptyxis)
    "org/gnome/Ptyxis" = {
      use-system-font = false;
      font-name = "JetBrainsMono Nerd Font Mono Regular 14";
    };

    # Interface visual padrão do GNOME (reverter configurações do Plasma)
    "org/gnome/desktop/interface" = {
      # Remove temas residuais do Plasma (Breeze)
      icon-theme = "Adwaita";
      # Fontes padrão do GNOME
      font-name = "Adwaita Regular 12"; # valor padrão: 11
      monospace-font-name = "Adwaita Mono 12"; # valor padrão: 11
      document-font-name = "Adwaita Regular 12"; # valor padrão: 11
    };

    # Cursor padrão do GNOME
    "org/gnome/desktop/sound" = {
      theme-name = "freedesktop";
    };

    # Layout da barra de título: sem ícone de app, sem minimizar/maximizar
    "org/gnome/desktop/wm/preferences" = {
      button-layout = ":close";
    };

    # Extensões GNOME habilitadas
    "org/gnome/shell" = {
      enabled-extensions = [ "ddterm@amezin.github.com" ];
    };
  };

  programs = {
    vscode = {
      enable = true;
      profiles.default.extensions =
        (with pkgs.vscode-extensions; [
          davidanson.vscode-markdownlint
          eamodio.gitlens
          github.codespaces
          github.copilot
          github.copilot-chat
          github.vscode-github-actions
          james-yu.latex-workshop
          jnoortheen.nix-ide
          mkhl.direnv
          ms-ceintl.vscode-language-pack-pt-br
          ms-vscode-remote.remote-containers
          pkief.material-icon-theme
          tecosaur.latex-utilities
          yzhang.markdown-all-in-one
        ])
        ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
          {
            name = "gabc-gregorian-chant-notation";
            publisher = "gregoriano-br";
            version = "1.1.0";
            sha256 = "sha256-Qcr5ceuV2qCEHTQWMAWqbhW3bJMFriHQlSfaBvpVibc=";
          }
          {
            name = "remotehub";
            publisher = "github";
            version = "0.64.0";
            sha256 = "sha256-Nh4PxYVdgdDb8iwHHUbXwJ5ZbMruFB6juL4Yg/wdKMY=";
          }
          {
            name = "lilypond-syntax";
            publisher = "jeandeaual";
            version = "0.1.1";
            sha256 = "sha256-Lo4Opa9PaMlCxLRx+6n6r2f/El2+N0gEMAO6cd9l7Fo=";
          }
          {
            name = "scheme";
            publisher = "jeandeaual";
            version = "0.2.0";
            sha256 = "sha256-ddehU7YeHv62QjZiTk0HV9wHgz8mVDuyMpH/w89bh6s=";
          }
          {
            name = "lilypond-formatter";
            publisher = "lhl2617";
            version = "0.2.3";
            sha256 = "sha256-4wjZKQvfqQpVlBvnR/s0Okipf7Xwhzol71uW0uOtk3k=";
          }
          {
            name = "lilypond-pdf-preview";
            publisher = "lhl2617";
            version = "0.2.8";
            sha256 = "sha256-otDRrc49Ej1So29quTX/evfotQbH/p+IeIb35votKi0=";
          }
          {
            name = "lilypond-snippets";
            publisher = "lhl2617";
            version = "0.1.1";
            sha256 = "sha256-Y/c5uxbTvOULNzJk8LOhVtTuzRa24sHnauUQhmIzHDU=";
          }
          {
            name = "vslilypond";
            publisher = "lhl2617";
            version = "1.7.3";
            sha256 = "sha256-zWs+kEu1YH5Vp/wPr/WrLmeblqIwKeqiH9difCaiYJs=";
          }
          {
            name = "extension-test-runner";
            publisher = "ms-vscode";
            version = "0.0.14";
            sha256 = "sha256-YkNSngj4oVlSOvG6RC6n9KhsV6Z5fcP14ah9qDejn3s=";
          }
          {
            name = "remote-repositories";
            publisher = "ms-vscode";
            version = "0.42.0";
            sha256 = "sha256-cYbkCcNsoTO6E5befw/ZN3yTW262APTCxyCJ/3z84dc=";
          }
        ];
    };

    # Direnv para automatizar a ativação de nix-shell / nix develop
    direnv.enable = true;

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
        # Ativar hook do direnv
        ''
          eval "$(direnv hook zsh)"
        ''
      ];
    };

    git = {
      signing = {
        key = "BAC0B1B569777A733E37447FB10712C404063D38";
        signByDefault = true;
      };
      settings = {
        user = {
          name = "abutre";
          email = "git@example.com";
        };
        tag.gpgsign = true;
        safe.directory = [ "/etc/nixos" ];
      };
    };
  };

}

