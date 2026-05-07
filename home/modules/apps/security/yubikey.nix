# Recursos de YubiKey para Home Manager (usuário)
{
  pkgs,
  desktop ? "gnome",
  ...
}:

let
  isPlasma = desktop == "plasma";
in

{
  home.packages = with pkgs; [
    yubikey-manager # provê o comando ykman
    yubioath-flutter # Yubico Authenticator
    pam_u2f # ferramenta pamu2fcfg para registrar chaves U2F
    yubico-piv-tool # operações PIV (certificados/chaves)
    gnupg # gpg/gpg-agent CLI
  ];

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

  home.sessionVariables = {
    U2F_KEYS_FILE = "$HOME/.config/Yubico/u2f_keys";
  };

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
