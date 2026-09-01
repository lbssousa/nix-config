# YubiKey resources for Home Manager (user)
{
  lib,
  pkgs,
  ...
}:

{
  home = {
    packages = with pkgs; [
      yubikey-manager # provides the ykman command
      yubioath-flutter # Yubico Authenticator
      pam_u2f # pamu2fcfg tool to register U2F keys
      yubico-piv-tool # PIV operations (certificates/keys)
      gnupg # gpg/gpg-agent CLI
      yubikey-gpg-import # imports/trusts the card's OpenPGP public key (scripts/import-gpg-yubikey.sh)
    ];

    sessionVariables = {
      U2F_KEYS_FILE = "$HOME/.config/Yubico/u2f_keys";
    };

    activation.refreshGpgAgentSockets = lib.hm.dag.entryBefore [ "reloadSystemd" ] ''
      systemctlUser=${lib.escapeShellArg "${pkgs.systemd}/bin/systemctl --user"}

      # gpg-agent in socket-activation mode needs to restart when the SSH
      # socket gets enabled/disabled; otherwise the already-running service
      # refuses the new gpg-agent-ssh.socket.
      for unit in gpg-agent-ssh.socket gpg-agent.socket gpg-agent.service; do
        $systemctlUser stop "$unit" 2>/dev/null || true
        $systemctlUser reset-failed "$unit" 2>/dev/null || true
      done
    '';

    activation.ensureGpgAgentSockets = lib.hm.dag.entryAfter [ "reloadSystemd" ] ''
      systemctlUser=${lib.escapeShellArg "${pkgs.systemd}/bin/systemctl --user"}

      $systemctlUser start gpg-agent.socket 2>/dev/null || true
    '';
  };

  programs.gpg = {
    enable = true;
    settings = {
      keyid-format = "0xlong";
      with-fingerprint = true;
    };
    # The YubiKey exposes OpenPGP via CCID. Since the system already uses
    # pcscd, we force scdaemon to talk via PC/SC to avoid contention over USB.
    scdaemonSettings = {
      disable-ccid = true;
    };
  };

  services.gpg-agent = {
    enable = true;
    enableScDaemon = true;
    enableSshSupport = false;
    enableZshIntegration = true;
    enableFishIntegration = true;
    defaultCacheTtl = 1800;
    maxCacheTtl = 7200;
    pinentry.package = pkgs.pinentry-gnome3;
  };

  # OpenSSH's native ssh-agent doesn't support ED25519-SK keys (YubiKey
  # resident keys) and returns "agent refused operation" when trying to use them.
  services.ssh-agent.enable = false;

  xdg.configFile."Yubico/README-pam_u2f.txt".text = ''
    Initial YubiKey registration for pam_u2f (per user):

    1) Create the U2F keys file with:
       mkdir -p ~/.config/Yubico
       pamu2fcfg > ~/.config/Yubico/u2f_keys

    2) To add more than one key, use append:
       pamu2fcfg -n >> ~/.config/Yubico/u2f_keys

     3) Configure PAM on the system to use:
        authfile=$HOME/.config/Yubico/u2f_keys
  '';

}
