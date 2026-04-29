# Módulo de usuário: Google Chrome via nixpkgs
# Instala o Google Chrome para o usuário via home-manager.
{ pkgs, ... }:

{
  home.packages = [ pkgs.google-chrome ];

  # Evita falha do HM quando mimeapps.list já existe fora do gerenciamento declarativo.
  xdg.configFile."mimeapps.list".force = true;
  xdg.dataFile."applications/mimeapps.list".force = true;

  # Definir Chrome como browser padrão do usuário via xdg-mime
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "google-chrome.desktop";
      "x-scheme-handler/http" = "google-chrome.desktop";
      "x-scheme-handler/https" = "google-chrome.desktop";
      "x-scheme-handler/about" = "google-chrome.desktop";
      "x-scheme-handler/unknown" = "google-chrome.desktop";
    };
  };
}
