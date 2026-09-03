# System support for YubiKey/SmartCard (pcscd) and, opt-in, FIDO2/U2F auth.
#
# PC/SC (smartcard access), fingerprint PAM wiring, and gnome-keyring are
# always on — they're independent of FIDO2/U2F. The pam_u2f-based PAM/PolKit
# authentication itself (security.pam.u2f + the per-service u2f.enable
# flags) is gated behind security.fido2Auth.enable, disabled by default:
# enable it per-host once a YubiKey is actually enrolled
# (see /persist/etc/u2f-mappings).
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.security.fido2Auth;
  wheelUsers = lib.attrNames (
    lib.filterAttrs (
      _name: user: (user.isNormalUser or false) && lib.elem "wheel" (user.extraGroups or [ ])
    ) config.users.users
  );
in
{
  options.security.fido2Auth = {
    enable = lib.mkEnableOption ''
      FIDO2/U2F-based PAM and PolKit authentication (pam_u2f, YubiKey touch)
      for sudo, run0, TTY login, the graphical greeter, and polkit/pkexec.
      Off by default — turn on per-host once a key is enrolled.
    '';
  };

  config = lib.mkMerge [
    {
      # Always on: PC/SC daemon (YubiKey PIV/OpenPGP, smartcards) and the
      # secret-service keyring daemon — unrelated to FIDO2/U2F.
      services.pcscd.enable = true;
      services.gnome.gnome-keyring.enable = true;

      security.pam.services = {
        # Sudo: fingerprint (sufficient) → password.
        # fprintd order 10700: before yubikey-notify (10850, only inserted
        # when security.fido2Auth.enable is true) and pam_u2f (10900).
        sudo.rules.auth.fprintd.order = lib.mkForce 10700;

        # run0 (systemd): authenticate once and remember for 5 minutes (pam_timestamp).
        # Order: timestamp (400) → fingerprint (500) → password (11700).
        # auth:    reads /run/pam_timestamp/<user>/run0:<tty>; if recent (< 5 min),
        #          returns success without re-authenticating.
        # session: writes the timestamp after a successful authentication,
        #          resetting the 5-minute window.
        # Note: linux-pam ≥ 1.7 uses /run/pam_timestamp (no longer /run/sudo).
        #       The directory is created via systemd.tmpfiles below.
        run0.rules = {
          auth = {
            fprintd.order = lib.mkForce 500;
            timestamp = {
              control = "sufficient";
              modulePath = "${pkgs.linux-pam}/lib/security/pam_timestamp.so";
              order = 400; # Before pam_fprintd (500)
            };
          };
          session.timestamp = {
            control = "optional";
            modulePath = "${pkgs.linux-pam}/lib/security/pam_timestamp.so";
            order = 500;
          };
        };

        # TTY console login (getty): password, keyring unlock on success.
        login.enableGnomeKeyring = true;

        # Graphical login (Noctalia Greeter, via greetd): fingerprint
        # (sufficient) → password, keyring unlock on success.
        # enableGnomeKeyring: unlocks the keyring on successful login —
        # despite the option name, gnome-keyring is a standalone
        # secret-service daemon (services.gnome.gnome-keyring above) used
        # regardless of desktop.
        greetd = {
          enableGnomeKeyring = true;
          fprintAuth = true;
        };

        # polkit/pkexec: fingerprint (sufficient) → password.
        # fprintd order 10700: before yubikey-notify (10850) and pam_u2f (10900).
        "polkit-1" = {
          fprintAuth = true;
          rules.auth.fprintd.order = lib.mkForce 10700;
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
    }

    (lib.mkIf cfg.enable {
      # Enables the U2F PAM module (pam_u2f) for YubiKey authentication.
      security.pam.u2f = {
        enable = true;
        settings = {
          cue = true;
          # interactive deliberately omitted: without this flag, pam_u2f
          # doesn't require "press Enter" via TTY before waiting for the key
          # touch. This lets Noctalia's polkit agent (programs.noctalia.settings
          # .shell.polkit_agent, see home/users/abutre/noctalia.nix) show the
          # graphical auth dialog — the user inserts the YubiKey and touches
          # the key without needing to interact with a terminal.
          authfile = "/persist/etc/u2f-mappings";
        };
      };

      security.pam.services = {
        sudo.u2f.enable = true;
        run0.u2f.enable = true;
        login.u2f.enable = true;
        greetd.u2f.enable = true;
        "polkit-1".u2f.enable = true;
      };

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
    })
  ];
}
