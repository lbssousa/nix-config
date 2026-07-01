# Recursos de YubiKey para Home Manager (usuário)
{
  lib,
  pkgs,
  ...
}:

{
  home = {
    packages = with pkgs; [
      yubikey-manager # provê o comando ykman
      yubioath-flutter # Yubico Authenticator
      pam_u2f # ferramenta pamu2fcfg para registrar chaves U2F
      yubico-piv-tool # operações PIV (certificados/chaves)
      gnupg # gpg/gpg-agent CLI
    ];

    sessionVariables = {
      U2F_KEYS_FILE = "$HOME/.config/Yubico/u2f_keys";
    };

    activation.refreshGpgAgentSockets = lib.hm.dag.entryBefore [ "reloadSystemd" ] ''
      systemctlUser=${lib.escapeShellArg "${pkgs.systemd}/bin/systemctl --user"}

      # O gpg-agent em modo socket activation precisa reiniciar quando o socket
      # SSH passa a ser habilitado/desabilitado; caso contrário, o serviço já
      # ativo recusa o novo gpg-agent-ssh.socket.
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
    # A YubiKey expõe OpenPGP via CCID. Como o sistema já usa pcscd,
    # forçamos o scdaemon a falar via PC/SC para evitar disputa pelo USB.
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

  # O ssh-agent nativo do OpenSSH não suporta chaves ED25519-SK (YubiKey
  # resident keys) e retorna "agent refused operation" ao tentar usá-las.
  services.ssh-agent.enable = false;

  xdg.configFile."Yubico/README-pam_u2f.txt".text = ''
    Registro inicial da YubiKey para pam_u2f (por usuário):

    1) Crie o arquivo de chaves U2F com:
       mkdir -p ~/.config/Yubico
       pamu2fcfg > ~/.config/Yubico/u2f_keys

    2) Para adicionar mais de uma chave, use append:
       pamu2fcfg -n >> ~/.config/Yubico/u2f_keys

     3) Configure o PAM no sistema para usar:
        authfile=$HOME/.config/Yubico/u2f_keys
  '';

}
