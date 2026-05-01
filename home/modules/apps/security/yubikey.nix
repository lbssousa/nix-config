# Recursos de YubiKey para Home Manager (usuário)
{ pkgs, ... }:

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
  };

  services.gpg-agent = {
    enable = true;
    enableScDaemon = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
    defaultCacheTtl = 1800;
    maxCacheTtl = 7200;
  };

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
