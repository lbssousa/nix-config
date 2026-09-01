# System support for Homebrew (Linuxbrew), available to every user similarly
# to Flatpak: a shared /home/linuxbrew/.linuxbrew prefix, group-writable by
# all normal users (see the "linuxbrew" extraGroup in users/mkUser.nix).
#
# Homebrew's own installer refuses to run as root, so the actual bootstrap
# and `brew bundle` steps run per-user via Home Manager
# (modules/home/apps/homebrew.nix) — this module only does what needs root:
# creating the shared prefix with the right ownership up front. Homebrew's
# installer checks whether its prefix is already writable by the invoking
# user before asking for sudo access, so pre-creating it here means the
# per-user bootstrap never needs to prompt for a password.
{ pkgs, ... }:

{
  users.groups.linuxbrew = { };

  systemd.tmpfiles.rules = [
    "d /home/linuxbrew            0755 root root      -"
    "d /home/linuxbrew/.linuxbrew 02775 root linuxbrew -"
  ];

  # Homebrew casks that are Electron/GTK apps (e.g. the VS Code swap in
  # modules/home/apps/homebrew.nix) are prebuilt Linux binaries, not NixOS
  # ones — they need nix-ld (already enabled in modules/system/desktop) plus
  # the usual Electron/GTK/X11 runtime libraries to find their shared
  # objects. This list is a reasonable starting point (confirmed against a
  # real "visual-studio-code-linux" cask run: it first failed on
  # libnspr4.so) — if a Homebrew-installed GUI app fails to start with an
  # "error while loading shared libraries: X.so" message, add the matching
  # package here.
  programs.nix-ld.libraries = with pkgs; [
    nspr
    nss
    glib
    gtk3
    cairo
    pango
    gdk-pixbuf
    atk
    at-spi2-atk
    at-spi2-core
    dbus
    expat
    fontconfig
    freetype
    cups
    mesa
    libdrm
    libxkbcommon
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
    libxshmfence
  ];
}
