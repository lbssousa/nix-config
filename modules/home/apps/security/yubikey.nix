# Recursos de YubiKey para Home Manager (usuário)
{
  lib,
  pkgs,
  osConfig,
  ...
}:

let
  isPlasma = osConfig.my.desktop.environment == "plasma";
in

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

      runIfUnitExists() {
        local action="$1"
        shift

        local unit loadState
        for unit in "$@"; do
          loadState="$($systemctlUser show --property=LoadState --value "$unit" 2>/dev/null || true)"

          if [ -n "$loadState" ] && [ "$loadState" != "not-found" ]; then
            $systemctlUser "$action" "$unit"
          fi
        done
      }

      # O gpg-agent em modo socket activation precisa reiniciar quando o socket
      # SSH passa a ser habilitado/desabilitado; caso contrário, o serviço já
      # ativo recusa o novo gpg-agent-ssh.socket.
      runIfUnitExists stop gpg-agent-ssh.socket gpg-agent.socket gpg-agent.service
      runIfUnitExists reset-failed gpg-agent-ssh.socket gpg-agent.socket gpg-agent.service
    '';

    activation.ensureGpgAgentSockets = lib.hm.dag.entryAfter [ "reloadSystemd" ] ''
      systemctlUser=${lib.escapeShellArg "${pkgs.systemd}/bin/systemctl --user"}

      runIfUnitExists() {
        local action="$1"
        shift

        local unit loadState
        for unit in "$@"; do
          loadState="$($systemctlUser show --property=LoadState --value "$unit" 2>/dev/null || true)"

          if [ -n "$loadState" ] && [ "$loadState" != "not-found" ]; then
            $systemctlUser "$action" "$unit"
          fi
        done
      }

      runIfUnitExists start gpg-agent.socket

      if [ "${osConfig.my.desktop.environment}" = "plasma" ]; then
        runIfUnitExists start gpg-agent-ssh.socket
      fi
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
    enableSshSupport = isPlasma;
    enableZshIntegration = true;
    enableFishIntegration = true;
    defaultCacheTtl = 1800;
    maxCacheTtl = 7200;
    # No Plasma, alinhamos o agente ao stack nativo do desktop (Kleopatra/KWallet + Qt).
    pinentry.package = if isPlasma then pkgs.pinentry-qt else pkgs.pinentry-gnome3;
  };

  # O ssh-agent nativo do OpenSSH não suporta chaves ED25519-SK (YubiKey
  # resident keys) e retorna "agent refused operation" ao tentar usá-las.
  # No Plasma usamos o suporte SSH do gpg-agent; fora dele mantemos sem agente.
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
