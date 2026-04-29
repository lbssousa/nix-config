# Configurações Home Manager específicas para o usuário laercio
{ pkgs, lib, ... }:

{
  imports = [
    ../../modules/apps/nix-validation.nix
  ];

  home = {
    username = lib.mkDefault "laercio";
    homeDirectory = lib.mkDefault "/home/laercio";
    packages = [
      pkgs.github-copilot-cli
      pkgs.kdePackages.yakuake
    ];
    # Garante que apps da sessão gráfica (ex: VSCode via launcher) usem o mesmo agent.
    sessionVariables.SSH_AUTH_SOCK = "$HOME/.var/app/com.bitwarden.desktop/data/.bitwarden-ssh-agent.sock";
  };

  # Exporta para a sessão systemd do usuário, cobrindo apps GUI iniciados fora do shell.
  xdg.configFile."environment.d/90-ssh-auth-sock.conf".text = ''
    SSH_AUTH_SOCK=$HOME/.var/app/com.bitwarden.desktop/data/.bitwarden-ssh-agent.sock
  '';

  xdg.configFile."konsolerc".text = ''
    [Desktop Entry]
    DefaultProfile=default.profile
  '';

  xdg.configFile."yakuakerc".text = ''
    [Desktop Entry]
    DefaultProfile=default.profile
  '';

  xdg.dataFile."konsole/default.profile".text = ''
    [Appearance]
    Font=JetBrainsMono Nerd Font Mono,14,-1,5,50,0,0,0,0,0

    [General]
    Name=Default
    Parent=FALLBACK/
  '';

  dconf.settings = {
    "org/gnome/Ptyxis" = {
      use-system-font = false;
      font-name = "JetBrainsMono Nerd Font Mono Regular 14";
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
        # O prefixo key:: é necessário para indicar que é uma chave inline (não um caminho de arquivo)
        key = "key::ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILc5RYDDiqlYAyO7xuDJPLFtx5cMEyN2io/qVsmv55N9 GitHub";
        signByDefault = true;
      };
      settings = {
        user = {
          name = "Laércio de Sousa";
          email = "laercio@sivali.sousa.nom.br";
        };
        gpg.format = "ssh";
        gpg.ssh.program = "/run/current-system/sw/bin/ssh-keygen";
        tag.gpgsign = true;
        safe.directory = [ "/etc/nixos" ];
      };
    };
  };
}
