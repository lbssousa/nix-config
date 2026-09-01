# Ghostty configuration — default desktop terminal
#
# To open without decorations (quake-style drop-down):
#   ghostty --window-decoration=false
#
# The 'com.mitchellh.ghostty.quake' desktop entry (hidden from the app menu)
# backs the F12 quake-style terminal, bound in home/users/abutre/noctalia.nix
# via an Umbriel keybind + scratchpad (window-move-to-scratchpad /
# scratchpad-toggle) instead of a GNOME Shell extension. The --class flag
# sets the GApplication ID (and therefore the Wayland app_id), which Umbriel's
# window_rule matches on to float the window instead of tiling it.
#
# Note: Ghostty 1.3.1 doesn't support [profile:name] in the config — flags
# are used directly on the command line instead.
_:

{
  xdg = {
    configFile."ghostty/config".text = ''
      # ── Font ───────────────────────────────────────────────────────────────
      font-family = JetBrainsMono Nerd Font
      font-size = 14

      # ── Appearance ─────────────────────────────────────────────────────────
      # Default profile: decorations on for normal use
      window-decoration = true

      # Tabs at the bottom: more visible when the window drops from the top
      gtk-tabs-location = bottom

      # Window opacity (90%)
      background-opacity = 0.90

      # GNOME palette (dark theme — matches Ptyxis's default)
      background = 171421
      foreground = D0CFCC
      palette = 0=#171421
      palette = 1=#C01C28
      palette = 2=#26A269
      palette = 3=#A2734C
      palette = 4=#12488B
      palette = 5=#A347BA
      palette = 6=#2AA1B3
      palette = 7=#D0CFCC
      palette = 8=#5E5C64
      palette = 9=#F66151
      palette = 10=#33D17A
      palette = 11=#E9AD0C
      palette = 12=#2A7BDE
      palette = 13=#C061CB
      palette = 14=#33C7DE
      palette = 15=#FFFFFF

      # Bold text uses the bright palette colors (indices 8–15)
      bold-color = bright

      # ── Behavior ───────────────────────────────────────────────────────────
      quit-after-last-window-closed = true
      confirm-close-surface = false
      bell-features = system

      # Disable auto-update (package managed by Nix)
      auto-update = off
    '';

    # Desktop entry hidden from the app menu, used by the quake-style F12 binding.
    # --class: sets the GApplication ID to com.mitchellh.ghostty.quake, which
    #   is what Umbriel's window_rule (home/users/abutre/noctalia.nix) matches
    #   on to float this window instead of tiling it.
    # --gtk-single-instance=false: prevents this instance from registering as
    #   a singleton GApplication. Without it, it would grab the single-instance
    #   slot and normally-opened windows would get routed to this process.
    desktopEntries."com.mitchellh.ghostty.quake" = {
      name = "Ghostty (Quake)";
      exec = "ghostty --window-decoration=false --gtk-single-instance=false --class=com.mitchellh.ghostty.quake";
      icon = "com.mitchellh.ghostty";
      noDisplay = true;
    };
  };
}
