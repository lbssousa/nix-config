# Configurações Home Manager específicas para o usuário abutre
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

let
  personalAgeKeySource = "${config.home.homeDirectory}/Documentos/lbssousa/nix-keys/sops/age/abutre/keys.txt";
  personalAgeKeyPath = "${config.xdg.configHome}/sops/age/keys.txt";
  rcloneConfigPath = "${config.xdg.configHome}/rclone/rclone.conf";
  rcloneGoogleDriveInstances = {
    my-drive = {
      mountDir = "Meu Drive";
      cacheSlug = "google-drive";
      extraFlags = "";
    };

    shared-with-me = {
      mountDir = "Compartilhados Comigo";
      cacheSlug = "google-drive-shared-with-me";
      extraFlags = "--drive-shared-with-me";
    };
  };

  mkRcloneGoogleDriveEnvFile =
    instanceName:
    {
      mountDir,
      cacheSlug,
      extraFlags,
    }:
    lib.nameValuePair "systemd/user/rclone-google-drive@${instanceName}.env" {
      text = ''
        MOUNT_DIR=${mountDir}
        CACHE_SLUG=${cacheSlug}
        EXTRA_FLAGS=${extraFlags}
      '';
    };

  # Script que escreve o rclone.conf em tempo de execução, substituindo apenas
  # as credenciais OAuth (client_id e client_secret) pelos valores decifrados
  # pelo sops-nix. Os demais campos são declarativos. O token OAuth gerenciado
  # pelo rclone é preservado entre ativações do home-manager.
  writeRcloneConfig = pkgs.writeShellScript "write-rclone-config" ''
    set -euo pipefail

    client_id=$(${pkgs.coreutils}/bin/cat "$SOPS_CLIENT_ID_PATH")
    client_secret=$(${pkgs.coreutils}/bin/cat "$SOPS_CLIENT_SECRET_PATH")

    ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "${rcloneConfigPath}")"

    # Preserva o token OAuth existente para evitar re-autenticação
    existing_token="token = "
    if [ -f "${rcloneConfigPath}" ]; then
      existing_token=$(${pkgs.gnugrep}/bin/grep "^token = " "${rcloneConfigPath}" \
        || ${pkgs.coreutils}/bin/true)
    fi

    ${pkgs.coreutils}/bin/printf '%s\n' \
      '[Google Drive]' \
      'type = drive' \
      "client_id = $client_id" \
      "client_secret = $client_secret" \
      'scope = drive' \
      "$existing_token" \
      'team_drive = ' \
      > "${rcloneConfigPath}"
  '';

in

{
  imports = [
    ../../../modules/home/apps/nix-validation.nix
    ../../../modules/home/apps/security/yubikey.nix
  ];

  home = {
    packages = [
      pkgs.github-copilot-cli
      pkgs.gcc
      pkgs.rclone
      pkgs.rustup
      pkgs.gnomeExtensions.appindicator
      pkgs.gnomeExtensions.ddterm
    ];
    # ~/.cargo/bin exposes rustup-managed shims (cargo, rustc, etc.) to the shell
    # and to Zed, which calls rustup to compile WASM extensions.
    sessionPath = [ "${config.home.homeDirectory}/.cargo/bin" ];
    # Cursor padrão do GNOME — configura Wayland, XWayland e o link ~/.icons/default
    pointerCursor = {
      package = pkgs.adwaita-icon-theme;
      name = "Adwaita";
      size = 24;
      gtk.enable = true;
    };

  };

  xdg.configFile = {
    "systemd/user/rclone-google-drive@.service".text = ''
      [Unit]
      Description=rclone: Remote FUSE filesystem for Google Drive (%i)
      Documentation=man:rclone(1)
      After=network-online.target rclone-write-config.service
      Wants=network-online.target
      Requires=rclone-write-config.service

      [Service]
      Type=notify
      Environment=PATH=/run/wrappers/bin:${lib.makeBinPath [ pkgs.fuse3 ]}
      EnvironmentFile=%h/.config/systemd/user/rclone-google-drive@%i.env
      EnvironmentFile=${config.xdg.configHome}/rclone/google-drive-email.env

      ExecStartPre=-${pkgs.bash}/bin/bash -lc 'exec ${pkgs.coreutils}/bin/mkdir -p "$HOME/Google Drive/$GOOGLE_DRIVE_EMAIL/$MOUNT_DIR"'

      ExecStart= \
        ${pkgs.bash}/bin/bash -lc 'exec ${pkgs.rclone}/bin/rclone mount \
          --config=${rcloneConfigPath} \
          --cache-dir="$HOME/.cache/rclone/vfs/$CACHE_SLUG" \
          --dir-cache-time 5000h \
          --poll-interval 10s \
          --vfs-cache-mode writes \
          --vfs-cache-max-size 10G \
          --vfs-read-chunk-size 120M \
          --vfs-read-ahead 1G \
          --vfs-cache-max-age 5000h \
          --bwlimit-file 100M \
          --log-level INFO \
          --log-file /tmp/rclone-google-drive-%i.log \
          --umask 022 \
          $EXTRA_FLAGS \
          "Google Drive:" "$HOME/Google Drive/$GOOGLE_DRIVE_EMAIL/$MOUNT_DIR"'

      ExecStop=${pkgs.bash}/bin/bash -lc 'exec /run/wrappers/bin/fusermount3 -uz "$HOME/Google Drive/$GOOGLE_DRIVE_EMAIL/$MOUNT_DIR"'
      Restart=on-failure
      RestartSec=10

      [Install]
      WantedBy=default.target
    '';

    "systemd/user/rclone-write-config.service".text = ''
      [Unit]
      Description=Escrever config do rclone com credenciais decifradas
      After=sops-nix.service
      Requires=sops-nix.service

      [Service]
      Type=oneshot
      RemainAfterExit=yes
      Environment=SOPS_CLIENT_ID_PATH=${config.sops.secrets."rclone-client-id".path}
      Environment=SOPS_CLIENT_SECRET_PATH=${config.sops.secrets."rclone-client-secret".path}
      ExecStart=${writeRcloneConfig}
    '';

    # Favoritos do Nautilus (gtk-3.0)
    "gtk-3.0/bookmarks" = {
      force = true;
      text = ''
        file://${config.home.homeDirectory}/Documentos
        file://${config.home.homeDirectory}/M%C3%BAsicas
        file://${config.home.homeDirectory}/Imagens
        file://${config.home.homeDirectory}/V%C3%ADdeos
        file://${config.home.homeDirectory}/Downloads
      '';
    };
  }
  // lib.mapAttrs' mkRcloneGoogleDriveEnvFile rcloneGoogleDriveInstances
  // {
    # Env file com o e-mail do Google Drive — não é segredo, vem do flake
    "rclone/google-drive-email.env".text =
      "GOOGLE_DRIVE_EMAIL=${inputs.nix-secrets.abutre.googleDriveEmail}";
  };

  home.activation.installPersonalSopsAgeKey = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -f ${lib.escapeShellArg personalAgeKeySource} ]; then
      echo "Chave age pessoal do sops não encontrada em ${personalAgeKeySource}" >&2
      exit 1
    fi

    ${pkgs.coreutils}/bin/install -Dm600 \
      ${lib.escapeShellArg personalAgeKeySource} \
      ${lib.escapeShellArg personalAgeKeyPath}
  '';

  home.activation.manageRcloneGoogleDriveServices = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    systemctlUser=${lib.escapeShellArg "${pkgs.systemd}/bin/systemctl --user"}
    systemdUserWantsDir=${lib.escapeShellArg "${config.xdg.configHome}/systemd/user/default.target.wants"}

    ${pkgs.coreutils}/bin/mkdir -p "$systemdUserWantsDir"

    ${pkgs.coreutils}/bin/ln -sfn ../rclone-google-drive@.service \
      "$systemdUserWantsDir/rclone-google-drive@my-drive.service"
    ${pkgs.coreutils}/bin/ln -sfn ../rclone-google-drive@.service \
      "$systemdUserWantsDir/rclone-google-drive@shared-with-me.service"

    $systemctlUser daemon-reload
    $systemctlUser reset-failed \
      rclone-google-drive@my-drive.service \
      rclone-google-drive@shared-with-me.service
    $systemctlUser restart rclone-google-drive@my-drive.service
    $systemctlUser restart rclone-google-drive@shared-with-me.service
  '';

  sops = {
    age.keyFile = personalAgeKeyPath;

    secrets."rclone-client-id" = {
      sopsFile = inputs.nix-secrets + "/secrets.yaml";
      key = "abutre/google_drive/rclone/client_id";
    };
    secrets."rclone-client-secret" = {
      sopsFile = inputs.nix-secrets + "/secrets.yaml";
      key = "abutre/google_drive/rclone/client_secret";
    };
  };

  dconf.settings = {
    # IBus em Wayland puro: delega layout ao sistema (evita setxkbmap) e
    # carrega a engine BR na inicialização da sessão.
    "desktop/ibus/general" = {
      use-system-keyboard-layout = true;
      preload-engines = [ "xkb:br::por" ];
    };

    "org/gnome/desktop/input-sources" = {
      sources = [
        (lib.hm.gvariant.mkTuple [
          "xkb"
          "br"
        ])
      ];
      mru-sources = [
        (lib.hm.gvariant.mkTuple [
          "xkb"
          "br"
        ])
      ];
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
      enabled-extensions = [
        "appindicatorsupport@rgcjonas.gmail.com"
        "ddterm@amezin.github.com"
      ];
    };
  };

  programs = {
    # programs.cargo manages ~/.cargo/config.toml; package = null avoids
    # installing pkgs.cargo alongside rustup's own cargo shim.
    cargo = {
      enable = true;
      package = null;
    };

    "zed-editor" = {
      enable = true;
      package = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.zed-editor;
      # Nota: "gregorio" é instalada localmente via xdg.dataFile + activation abaixo;
      # não deve estar aqui ou o Zed tentará instalá-la do marketplace e esvaziará
      # o diretório installed/gregorio/.
      extensions = [
        "nix"
        "latex"
      ];
      extraPackages = with pkgs; [
        direnv
        nil
        nixd
        texlab
        ltex-ls
        gregolint
        gregorio-lsp
      ];
      userSettings = {
        theme = {
          mode = "dark";
          dark = "One Dark";
          light = "One Light";
        };
        load_direnv = "direct";
        soft_wrap = "bounded";
        autosave = {
          after_delay = {
            milliseconds = 1000;
          };
        };
        vim_mode = false;
        hour_format = "hour24";
        buffer_font_family = "ZedMono Nerd Font Mono";
        buffer_font_size = 24;
        terminal = {
          font_family = "JetBrainsMono Nerd Font Mono";
          font_size = 24;
        };
        lsp = {
          nil.binary.path = "${pkgs.nil}/bin/nil";
          nixd.binary.path = "${pkgs.nixd}/bin/nixd";
          texlab.binary.path = "${pkgs.texlab}/bin/texlab";
          "ltex-ls".binary.path = "${pkgs.ltex-ls}/bin/ltex-ls";
          "gregorio-lsp".binary.path = "${pkgs.gregorio-lsp}/bin/gregorio-lsp";
        };
      };
    };

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
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

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
        user.name = inputs.nix-secrets.abutre.gitName;
        user.email = inputs.nix-secrets.abutre.gitEmail;
        safe.directory = [ "/etc/nixos" ];
      };

    };

    ssh.enable = true;
  };

}
