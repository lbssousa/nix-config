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
in

{
  imports = [
    ../../../modules/home/apps/browsers/firefox.nix
    ../../../modules/home/apps/browsers/microsoft-edge.nix
    ../../../modules/home/apps/nix-validation.nix
    ../../../modules/home/apps/security/yubikey.nix
    ../../../modules/home/apps/editors/zed.nix
    ./gnome.nix
    ./rclone.nix
    ./vscode.nix
  ];

  home = {
    packages = [
      pkgs.github-copilot-cli
      pkgs.gcc
      pkgs.grelint
      pkgs.rustup
    ];
    # ~/.cargo/bin exposes rustup-managed shims (cargo, rustc, etc.) to the shell
    # and to Zed, which calls rustup to compile WASM extensions.
    sessionPath = [ "${config.home.homeDirectory}/.cargo/bin" ];
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

  sops.age.keyFile = personalAgeKeyPath;

  programs = {
    # programs.cargo manages ~/.cargo/config.toml; package = null avoids
    # installing pkgs.cargo alongside rustup's own cargo shim.
    cargo = {
      enable = true;
      package = null;
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
