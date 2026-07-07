# GNOME configuration for the abutre user
{ pkgs, ... }:

{
  home.packages = with pkgs.gnomeExtensions; [
    appindicator
    caffeine
    quake-terminal
  ];

  xdg.mimeApps.defaultApplications = {
    "application/pdf" = "org.gnome.Papers.desktop";
    "application/x-bzpdf" = "org.gnome.Papers.desktop";
    "application/x-gzpdf" = "org.gnome.Papers.desktop";
    "application/x-xzpdf" = "org.gnome.Papers.desktop";
    "application/x-ext-pdf" = "org.gnome.Papers.desktop";
  };

  # Note: dconf settings are not declared here with dconf.settings.
  # With an ephemeral home, dconf.settings only writes to
  # ~/.config/dconf/user on home-manager switch — getting lost on the next
  # reboot. Declare in programs.dconf.profiles.*.databases on the NixOS
  # side instead (see gnome-wrapper.nix).
}
