# Suporte de sistema para YubiKey/SmartCard (pcscd)
{ ... }:

{
  services.pcscd.enable = true;

  security.pam = {
    # Habilita o módulo PAM U2F (pam_u2f) para autenticação com YubiKey.
    u2f = {
      enable = true;
      settings = {
        cue = true;
        interactive = true;
        # Arquivo de mapeamento global do pam_u2f persistido fora da raiz efêmera.
        authfile = "/persist/etc/u2f-mappings";
      };
    };

    # Permite autenticar comandos sudo com YubiKey.
    services.sudo.u2fAuth = true;
  };
}
