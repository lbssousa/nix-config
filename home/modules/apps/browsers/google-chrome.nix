# Módulo de usuário: Google Chrome via módulo nativo do Home Manager
{ pkgs, ... }:

{
  programs.google-chrome = {
    enable = true;
    package = pkgs.google-chrome;
  };

  xdg = {
    # Evita falha do HM quando mimeapps.list já existe fora do gerenciamento declarativo.
    configFile."mimeapps.list".force = true;
    dataFile."applications/mimeapps.list".force = true;

    # Definir Chrome como browser padrão do usuário via xdg-mime
    mimeApps = {
      enable = true;
      defaultApplications = {
        "text/html" = "google-chrome.desktop";
        "x-scheme-handler/http" = "google-chrome.desktop";
        "x-scheme-handler/https" = "google-chrome.desktop";
        "x-scheme-handler/about" = "google-chrome.desktop";
        "x-scheme-handler/unknown" = "google-chrome.desktop";
      };
    };
  };
}
