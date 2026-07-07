# System support for YubiKey/SmartCard (pcscd)
{
  config,
  lib,
  pkgs,
  ...
}:

let
  wheelUsers = lib.attrNames (
    lib.filterAttrs (
      _name: user: (user.isNormalUser or false) && lib.elem "wheel" (user.extraGroups or [ ])
    ) config.users.users
  );
in
{
  services.pcscd.enable = true;
  services.gnome.gnome-keyring.enable = true;

  security.pam = {
    # Enables the U2F PAM module (pam_u2f) for YubiKey authentication.
    u2f = {
      enable = true;
      settings = {
        cue = true;
        # interactive deliberately omitted: without this flag, pam_u2f
        # doesn't require "press Enter" via TTY before waiting for the key
        # touch. This lets GNOME's polkit agent (built into gnome-shell)
        # show the graphical auth dialog — the user inserts the YubiKey and
        # touches the key without needing to interact with a terminal.
        authfile = "/persist/etc/u2f-mappings";
      };
    };

    services = {
      # Sudo: fingerprint (sufficient) → YubiKey (sufficient) → password.
      # fprintd order 10700: before yubikey-notify (10850) and pam_u2f (10900).
      sudo = {
        u2f.enable = true;
        rules.auth.fprintd.order = lib.mkForce 10700;
      };

      # run0 (systemd): authenticate once and remember for 5 minutes (pam_timestamp).
      # Order: timestamp (400) → fingerprint (500) → YubiKey (10900) → password (11700).
      # auth:    reads /run/pam_timestamp/<user>/run0:<tty>; if recent (< 5 min),
      #          returns success without re-authenticating.
      # session: writes the timestamp after a successful authentication,
      #          resetting the 5-minute window.
      # Note: linux-pam ≥ 1.7 uses /run/pam_timestamp (no longer /run/sudo).
      #       The directory is created via systemd.tmpfiles below.
      run0 = {
        u2f.enable = true;
        rules = {
          auth = {
            fprintd.order = lib.mkForce 500;
            timestamp = {
              control = "sufficient";
              modulePath = "${pkgs.linux-pam}/lib/security/pam_timestamp.so";
              order = 400; # Before pam_fprintd (500) and pam_u2f (10900)
            };
          };
          session.timestamp = {
            control = "optional";
            modulePath = "${pkgs.linux-pam}/lib/security/pam_timestamp.so";
            order = 500;
          };
        };
      };

      # Login: YubiKey → password.
      # Note: nixpkgs' gdm.nix explicitly sets login.fprintAuth = false,
      # since GNOME uses gdm-fingerprint as a separate PAM service for fingerprints.
      login = {
        u2f.enable = true;
        enableGnomeKeyring = true;
      };

      # polkit/pkexec: fingerprint (sufficient) → YubiKey (sufficient) → password.
      # fprintd order 10700: before yubikey-notify (10850) and pam_u2f (10900).
      "polkit-1" = {
        u2f.enable = true;
        fprintAuth = true;
        rules.auth.fprintd.order = lib.mkForce 10700;
      };
    };
  };

  # pam_timestamp's timestamp directory (linux-pam ≥ 1.7).
  # pam_timestamp doesn't create the parent directory — without it, the
  # session module fails silently (control "optional") and the cache is
  # never written.
  systemd.tmpfiles.rules = [
    "d /run/pam_timestamp 0700 root root -"
    "d /run/sudo          0700 root root -" # sudo compatibility
  ];

  # Automatic check on switch/rebuild to avoid a sudo lockout.
  system.activationScripts.checkPamU2FMapping = {
    deps = [ "users" ];
    text = ''
      authfile="/persist/etc/u2f-mappings"

      if [ ! -f "$authfile" ]; then
        echo "WARNING: $authfile does not exist. sudo with YubiKey (pam_u2f) will fail." >&2
      else
        for user in ${lib.concatStringsSep " " (map lib.escapeShellArg wheelUsers)}; do
          if ! grep -q "^${"$"}user:" "$authfile"; then
            echo "WARNING: $authfile has no entry for '${"$"}user' (wheel group)." >&2
          fi
        done
      fi
    '';
  };
}
