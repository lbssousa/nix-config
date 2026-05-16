# Módulo de usuário: Microsoft Edge como navegador adicional
{ pkgs, ... }:

{
  home.packages = [ pkgs.microsoft-edge ];

  xdg = {
    # Evita falha do HM quando mimeapps.list já existe fora do gerenciamento declarativo.
    configFile."mimeapps.list".force = true;
    dataFile."applications/mimeapps.list".force = true;

    mimeApps = {
      enable = true;
      associations.added = {
        "text/html" = "microsoft-edge.desktop";
        "x-scheme-handler/http" = "microsoft-edge.desktop";
        "x-scheme-handler/https" = "microsoft-edge.desktop";
        "x-scheme-handler/about" = "microsoft-edge.desktop";
        "x-scheme-handler/unknown" = "microsoft-edge.desktop";
      };
    };
  };
}
