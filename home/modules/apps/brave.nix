# Módulo de usuário: Brave Browser via nixpkgs
# Instala o Brave Browser para o usuário via home-manager.
# O Brave também é instalado system-wide via Flatpak (desktop.nix),
# portanto este módulo é opcional e pode ser usado como alternativa.
{ pkgs, ... }:

{
  home.packages = [ pkgs.brave ];

  # Definir Brave como browser padrão do usuário via xdg-mime
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "brave-browser.desktop";
      "x-scheme-handler/http" = "brave-browser.desktop";
      "x-scheme-handler/https" = "brave-browser.desktop";
      "x-scheme-handler/about" = "brave-browser.desktop";
      "x-scheme-handler/unknown" = "brave-browser.desktop";
    };
  };
}
