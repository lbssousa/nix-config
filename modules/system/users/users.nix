# Users module: skeleton for defining users
# User files live in users/ (public — they only contain aliases)
# See users/skeleton.nix to create your user file
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Normal users with an initial password declared (initialPassword or initialHashedPassword).
  # For these users the system forces a password change on first login,
  # using a flag file in /persist so the requirement only fires once.
  usersWithInitialPassword = lib.filterAttrs (
    _name: user:
    user.isNormalUser && (user.initialPassword != null || user.initialHashedPassword != null)
  ) config.users.users;
in
{
  # Enable Zsh globally (needed to use it as a user shell)
  programs.zsh.enable = true;
  programs.fish.enable = true;

  # Default sudo configuration
  security.sudo = {
    enable = true;
    wheelNeedsPassword = true;
  };

  # Users are defined in separate files under users/
  # Example: users/abutre.nix
  # To create a user, copy users/skeleton.nix to users/<your-username>.nix
  # and uncomment/adjust the settings

  # Default group configuration available
  users.groups = {
    plugdev = { }; # USB device access
    dialout = { }; # Serial ports
    video = { }; # GPU access
    audio = { }; # Audio access
    docker = { }; # Docker compatibility (Podman)
  };

  # ─────────────────────────────────────────────────────────────────────────
  # /etc/shadow persistence (user passwords)
  # ─────────────────────────────────────────────────────────────────────────
  #
  # ROOT CAUSE: both NixOS's 'users' activation script and tools like
  # 'passwd' and 'chage' update /etc/shadow via an atomic rename(). Any bind
  # mount on /etc/shadow gets undone the instant the rename happens, turning
  # the bind-mounted file into an orphaned inode. With tmpfs on the root
  # (/), the newly created /etc/shadow only lives in RAM and is lost on the
  # next boot.
  #
  # TWO-STEP SOLUTION:
  #
  # 1. 'restoreShadow' activation script (deps = ["etc"]) — runs BEFORE
  #    'users' (via system.activationScripts.users.deps below):
  #    Copies /persist/etc/shadow → /etc/shadow if it exists, without a
  #    bind mount. Since 'users' has users.mutableUsers = true (NixOS
  #    default), when it reads the restored /etc/shadow it PRESERVES the
  #    existing users' passwords in the new shadow output, instead of
  #    applying initialPassword.
  #
  # 2. 'persistShadow' systemd service (path unit PathChanged=/etc/shadow):
  #    Watches /etc/shadow with inotify (PathChanged detects IN_MOVED_TO,
  #    i.e. rename). Every time /etc/shadow changes — whether via 'passwd',
  #    'chage', or the 'users' activation script — it immediately copies
  #    /etc/shadow → /persist/etc/shadow, ensuring persistence.
  system.activationScripts.restoreShadow = {
    deps = [ "etc" ];
    text = ''
      mkdir -p /persist/etc
      if [ -f /persist/etc/shadow ]; then
        # Restore the persisted shadow BEFORE the 'users' script runs.
        # With users.mutableUsers = true (NixOS default), the 'users'
        # script will read this file and preserve existing users' passwords.
        install -m 640 /persist/etc/shadow /etc/shadow
      fi
    '';
  };

  # Ensures the 'users' script waits for 'restoreShadow' to finish, so it
  # reads the already-restored /etc/shadow.
  system.activationScripts.users.deps = [ "restoreShadow" ];

  systemd = {
    # Write permission on /etc/nixos for the wheel group.
    # The real directory lives at /persist/etc/nixos (bind mount via preservation).
    # The 'z' rule adjusts owner and mode without wiping existing content.
    tmpfiles.rules = [ "z /persist/etc/nixos 0775 root wheel - -" ];

    # Watches /etc/shadow and persists every change to /persist/etc/shadow.
    # PathChanged catches IN_MOVED_TO (atomic rename from 'passwd'/'chage'/'users')
    # as well as IN_CLOSE_WRITE (direct write). The service is oneshot and idempotent.
    paths.persistShadow = {
      description = "Watch /etc/shadow to persist password changes";
      wantedBy = [ "multi-user.target" ];
      pathConfig = {
        PathChanged = "/etc/shadow";
        Unit = "persistShadow.service";
      };
    };

    services = {
      persistShadow = {
        description = "Persist /etc/shadow to /persist/etc/shadow";
        serviceConfig = {
          Type = "oneshot";
        };
        script = ''
          mkdir -p /persist/etc
          if [ -f /etc/shadow ]; then
            ${pkgs.coreutils}/bin/install -m 640 /etc/shadow /persist/etc/shadow
          fi
        '';
      };

      # Forces a password change on first login for users with
      # initialPassword/initialHashedPassword.
      # Uses a flag file in /persist so the change is only required once.
      #
      # Starts after 'persistShadow.path' (above), ensuring the inotify
      # watch is already active when 'chage -d 0' modifies /etc/shadow.
      # This way the change is immediately copied to /persist/etc/shadow by
      # persistShadow.service.
      #
      # To reset: delete /persist/.password-change-required-<user> and reboot.
      forceInitialPasswordChange = lib.mkIf (usersWithInitialPassword != { }) {
        description = "Force password change on first login (users with an initial password)";
        wantedBy = [ "multi-user.target" ];
        after = [
          "local-fs.target"
          "persistShadow.path"
        ];
        wants = [ "persistShadow.path" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = lib.concatMapStrings (
          username:
          let
            flagFile = lib.escapeShellArg "/persist/.password-change-required-${username}";
            escapedUser = lib.escapeShellArg username;
          in
          ''
            if [ ! -f ${flagFile} ]; then
              if ${pkgs.shadow}/bin/chage -d 0 ${escapedUser}; then
                touch ${flagFile}
              else
                echo "forceInitialPasswordChange: chage failed for ${escapedUser}" >&2
              fi
            fi
          ''
        ) (lib.attrNames usersWithInitialPassword);
      };
    };
  };
}
