# Módulo de usuário: Firefox Flatpak — navegador padrão para todos os usuários
#
# O Firefox é instalado como Flatpak (org.mozilla.firefox) — não via programs.firefox,
# que só gerencia o pacote Nix. Extensões e perfil são configurados manualmente.
_: {
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "org.mozilla.firefox.desktop";
      "x-scheme-handler/http" = "org.mozilla.firefox.desktop";
      "x-scheme-handler/https" = "org.mozilla.firefox.desktop";
      "x-scheme-handler/about" = "org.mozilla.firefox.desktop";
      "x-scheme-handler/unknown" = "org.mozilla.firefox.desktop";
    };
  };
}
