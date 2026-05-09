# Suporte de sistema para YubiKey/SmartCard (pcscd)
{ config, lib, ... }:

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
    # Habilita o módulo PAM U2F (pam_u2f) para autenticação com YubiKey.
    u2f = {
      enable = true;
      settings = {
        cue = true;
        # interactive deliberadamente omitido: sem esse flag, pam_u2f não exige
        # "pressione Enter" via TTY antes de aguardar o toque na chave. Isso
        # permite que o agente polkit do GNOME (embutido no gnome-shell) exiba
        # o dialog gráfico de autenticação — o usuário insere a YubiKey e toca
        # a chave sem precisar interagir com um terminal.
        authfile = "/persist/etc/u2f-mappings";
      };
    };

    services = {
      # Sudo autenticado por YubiKey (pam_u2f), sem fallback para senha/fingerprint.
      sudo = {
        u2f.enable = true;
        unixAuth = false;
        fprintAuth = false;
      };

      # Login do usuário com YubiKey.
      # Mantemos fallback de senha para evitar lockout em caso de ausência da chave.
      login = {
        u2f.enable = true;
        enableGnomeKeyring = true;
      };

      plasmalogin = {
        u2f.enable = true;
        enableGnomeKeyring = false;
        kwallet.enable = true;
      };

      # pkexec/polkit autenticado por YubiKey (pam_u2f), sem fallback para senha/fingerprint.
      "polkit-1" = {
        u2f.enable = true;
        unixAuth = false;
        fprintAuth = false;
      };
    };
  };

  # Checagem automática no switch/rebuild para evitar lockout em sudo.
  system.activationScripts.checkPamU2FMapping = {
    deps = [ "users" ];
    text = ''
      authfile="/persist/etc/u2f-mappings"

      if [ ! -f "$authfile" ]; then
        echo "WARNING: $authfile não existe. O sudo com YubiKey (pam_u2f) vai falhar." >&2
      else
        for user in ${lib.concatStringsSep " " (map lib.escapeShellArg wheelUsers)}; do
          if ! grep -q "^${"$"}user:" "$authfile"; then
            echo "WARNING: $authfile não possui entrada para '${"$"}user' (grupo wheel)." >&2
          fi
        done
      fi
    '';
  };
}
