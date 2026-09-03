# Home Manager configuration specific to the abutre user
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

let
  personalAgeKeyPath = "${config.xdg.configHome}/sops/age/keys.txt";
in

{
  imports = [
    ../../../modules/home/apps/nix-validation.nix
    ../../../modules/home/apps/security/keepassxc.nix
    ../../../modules/home/apps/security/yubikey.nix
    ../../../modules/home/apps/editors/helix
    ../../../modules/home/apps/editors/zed.nix
    ../../../modules/home/apps/editors/nixvim
    ../../../modules/home/apps/terminals/ghostty.nix
    ../../../modules/home/apps/terminals/tmux.nix
    ../../../modules/home/apps/terminals/herdr.nix

    ./noctalia.nix
    # ./rclone.nix  # disabled until Google Drive OAuth reauthentication
    ./vscode.nix
    ./fish.nix
    ./zsh.nix
  ];

  home = {
    # ~/.cargo/bin exposes rustup-managed shims (cargo, rustc, etc.) to the shell
    # and to Zed, which calls rustup to compile WASM extensions.
    sessionPath = [ "${config.home.homeDirectory}/.cargo/bin" ];
  };

  home.activation.installPersonalSopsAgeKey = lib.hm.dag.entryBefore [ "reloadSystemd" ] ''
    personalAgeKeySource="$(${pkgs.xdg-user-dirs}/bin/xdg-user-dir PROJECTS)/lbssousa/nix-keys/sops/age/abutre/keys.txt"
    if [ ! -f "$personalAgeKeySource" ]; then
      if [ ! -f ${lib.escapeShellArg personalAgeKeyPath} ]; then
        echo "Personal sops age key not found at $personalAgeKeySource" >&2
        exit 1
      fi
    elif ! ${pkgs.gnugrep}/bin/grep -q '^AGE-SECRET-KEY-' "$personalAgeKeySource"; then
      echo "nix-keys repository is locked (git-crypt). Run:" >&2
      echo "  gpg --card-status && git-crypt unlock \"\$(${pkgs.xdg-user-dirs}/bin/xdg-user-dir PROJECTS)/lbssousa/nix-keys\"" >&2
      if [ ! -f ${lib.escapeShellArg personalAgeKeyPath} ]; then
        exit 1
      fi
    else
      ${pkgs.coreutils}/bin/install -Dm600 \
        "$personalAgeKeySource" \
        ${lib.escapeShellArg personalAgeKeyPath}
    fi
  '';

  sops.age.keyFile = personalAgeKeyPath;

  programs = {
    # programs.cargo manages ~/.cargo/config.toml; package = null avoids
    # installing pkgs.cargo alongside rustup's own cargo shim.
    cargo = {
      enable = true;
      package = null;
    };

    # Direnv to automate nix-shell / nix develop activation
    direnv = {
      enable = true;
      nix-direnv.enable = true;
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
