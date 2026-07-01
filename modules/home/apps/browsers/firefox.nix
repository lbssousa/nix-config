# Módulo de usuário: Firefox — navegador padrão para todos os usuários
{ config, pkgs, ... }:

let
  buildFirefoxXpiAddon =
    {
      name,
      addonId,
      url,
      sha256,
    }:
    pkgs.stdenv.mkDerivation {
      inherit name;
      src = pkgs.fetchurl { inherit url sha256; };
      dontUnpack = true;
      passthru = { inherit addonId; };
      installPhase = ''
        mkdir -p "$out/share/mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}"
        cp "$src" "$out/share/mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}/${addonId}.xpi"
      '';
    };

  keepassxcBrowser = buildFirefoxXpiAddon {
    name = "keepassxc-browser";
    addonId = "keepassxc-browser@keepassxc.org";
    url = "https://addons.mozilla.org/firefox/downloads/file/4831838/keepassxc_browser-1.10.3.xpi";
    sha256 = "sha256-TfnFTgopOqLjfpvPl+wwejWgDnjOuqmmjtulUsB8RWg=";
  };

  bitwarden = buildFirefoxXpiAddon {
    name = "bitwarden";
    addonId = "{446900e4-71c2-419f-a6a7-df9c091e268b}";
    url = "https://addons.mozilla.org/firefox/downloads/file/4796063/bitwarden_password_manager-2026.4.0.xpi";
    sha256 = "sha256-zL32w6EchlXU/pvfz18WxMn/LYcy+tu4U5aiEjJ0rhA=";
  };

  multiAccountContainers = buildFirefoxXpiAddon {
    name = "multi-account-containers";
    addonId = "@testpilot-containers";
    url = "https://addons.mozilla.org/firefox/downloads/file/4733069/multi_account_containers-8.3.7.xpi";
    sha256 = "sha256-f29e97EG0z0bmdLF5TogZdB/eEsYUv6bn3g5TptAUWU=";
  };

  facebookContainer = buildFirefoxXpiAddon {
    name = "facebook-container";
    addonId = "@contain-facebook";
    url = "https://addons.mozilla.org/firefox/downloads/file/4451874/facebook_container-2.3.12.xpi";
    sha256 = "sha256-M2m9hlh3hg5tfTg5nVkCswDT1XN6yy0TQv9b6x03gME=";
  };

  ublockOrigin = buildFirefoxXpiAddon {
    name = "ublock-origin";
    addonId = "uBlock0@raymondhill.net";
    url = "https://addons.mozilla.org/firefox/downloads/file/4721638/ublock_origin-1.70.0.xpi";
    sha256 = "sha256-8nMNKHcAV2OkXXZXSYkuk29JyucT0o96puoxRFS4nPE=";
  };
in
{
  home = {
    packages = [ pkgs.hunspellDicts.pt_BR ];
    sessionVariables.DICPATH = "${pkgs.hunspellDicts.pt_BR}/share/hunspell";
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "firefox.desktop";
      "x-scheme-handler/http" = "firefox.desktop";
      "x-scheme-handler/https" = "firefox.desktop";
      "x-scheme-handler/about" = "firefox.desktop";
      "x-scheme-handler/unknown" = "firefox.desktop";
    };
  };

  programs.firefox = {
    enable = true;
    package = pkgs.firefox;
    languagePacks = [ "pt-BR" ];
    # Usa o caminho XDG (padrão do HM 26.05).
    configPath = "${config.xdg.configHome}/mozilla/firefox";

    profiles.default = {
      isDefault = true;
      settings = {
        "intl.locale.requested" = "pt-BR";
        "intl.accept_languages" = "pt-BR, pt, en-US, en";
        # Verificação ortográfica em português — inclui contenteditable (ex.: WhatsApp Web)
        "layout.spellcheckDefault" = 2;
        "spellchecker.dictionary" = "pt-BR";
        # Habilitar decodificação de vídeo por hardware via VA-API.
        # Necessário para transmissões ao vivo do YouTube (H.264/VP9)
        # e para reduzir o uso de CPU em vídeos em geral no Wayland.
        "media.ffmpeg.vaapi.enabled" = true;
        "media.hardware-video-decoding.enabled" = true;
      };
      extensions.packages = [
        keepassxcBrowser
        bitwarden
        multiAccountContainers
        facebookContainer
        ublockOrigin
      ];
    };
  };

}
