# Configuração do rclone com Google Drive para o usuário abutre
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

let
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
  home.packages = [ pkgs.rclone ];

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

    # Env file com o e-mail do Google Drive — não é segredo, vem do flake
    "rclone/google-drive-email.env".text =
      "GOOGLE_DRIVE_EMAIL=${inputs.nix-secrets.abutre.googleDriveEmail}";
  }
  // lib.mapAttrs' mkRcloneGoogleDriveEnvFile rcloneGoogleDriveInstances;

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

  sops.secrets."rclone-client-id" = {
    sopsFile = inputs.nix-secrets + "/secrets.yaml";
    key = "abutre/google_drive/rclone/client_id";
  };
  sops.secrets."rclone-client-secret" = {
    sopsFile = inputs.nix-secrets + "/secrets.yaml";
    key = "abutre/google_drive/rclone/client_secret";
  };
}
