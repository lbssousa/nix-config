# Módulo de usuário: Firefox com extensões via módulo nativo do Home Manager
{ pkgs, ... }:

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
    url = "https://addons.mozilla.org/firefox/downloads/file/4750788/keepassxc_browser-1.10.1.xpi";
    sha256 = "sha256-81hHHn9VRaZKtp9IlxJwMxl6jZzeV0YySx2uJBorCik=";
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
  programs.firefox = {
    enable = true;
    package = pkgs.firefox;

    profiles.default = {
      isDefault = true;
      extensions.packages = [
        keepassxcBrowser
        multiAccountContainers
        facebookContainer
        ublockOrigin
      ];
    };
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
}
