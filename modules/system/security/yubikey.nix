# Suporte de sistema para YubiKey/SmartCard (pcscd)
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
      # Sudo: digital (suficiente) → YubiKey (suficiente) → senha.
      # fprintd order 10700: antes do yubikey-notify (10850) e pam_u2f (10900).
      sudo = {
        u2f.enable = true;
        rules.auth.fprintd.order = lib.mkForce 10700;
      };

      # run0 (systemd): autentica uma vez e memoriza por 5 minutos (pam_timestamp).
      # Ordem: timestamp (400) → digital (500) → YubiKey (10900) → senha (11700).
      # auth:    lê /run/pam_timestamp/<user>/run0:<tty>; se recente (< 5 min),
      #          retorna sucesso sem nova autenticação.
      # session: grava o timestamp após autenticação bem-sucedida,
      #          reiniciando a janela de 5 minutos.
      # Nota: linux-pam ≥ 1.7 usa /run/pam_timestamp (não mais /run/sudo).
      #       O diretório é criado via systemd.tmpfiles abaixo.
      run0 = {
        u2f.enable = true;
        rules = {
          auth = {
            fprintd.order = lib.mkForce 500;
            timestamp = {
              control = "sufficient";
              modulePath = "${pkgs.linux-pam}/lib/security/pam_timestamp.so";
              order = 400; # Antes do pam_fprintd (500) e pam_u2f (10900)
            };
          };
          session.timestamp = {
            control = "optional";
            modulePath = "${pkgs.linux-pam}/lib/security/pam_timestamp.so";
            order = 500;
          };
        };
      };

      # Login: YubiKey → senha.
      # Nota: gdm.nix do nixpkgs define login.fprintAuth = false explicitamente,
      # pois o GNOME usa gdm-fingerprint como serviço PAM separado para digitais.
      login = {
        u2f.enable = true;
        enableGnomeKeyring = true;
      };

      # polkit/pkexec: digital (suficiente) → YubiKey (suficiente) → senha.
      # fprintd order 10700: antes do yubikey-notify (10850) e pam_u2f (10900).
      "polkit-1" = {
        u2f.enable = true;
        fprintAuth = true;
        rules.auth.fprintd.order = lib.mkForce 10700;
      };
    };
  };

  # Diretório de timestamps do pam_timestamp (linux-pam ≥ 1.7).
  # O pam_timestamp não cria o diretório pai — sem ele, o módulo session
  # falha silenciosamente (controle "optional") e o cache nunca é gravado.
  systemd.tmpfiles.rules = [
    "d /run/pam_timestamp 0700 root root -"
    "d /run/sudo          0700 root root -" # compatibilidade com sudo
  ];

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
