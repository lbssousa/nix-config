# User module: Firefox Flatpak — default browser for all users
#
# Firefox is installed as a Flatpak (org.mozilla.firefox) — not via programs.firefox,
# which only manages the Nix package. Extensions and profile are configured manually.
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
