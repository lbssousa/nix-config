# Noctalia configuration for the abutre user: compositor (Umbriel) and shell.
_:

{
  # ── Compositor: Umbriel ────────────────────────────────────────────────
  programs.umbriel = {
    enable = true;
    settings = {
      general.autostart = [ "noctalia" ];

      # br+abnt2 layout for the session.
      # Mirrors services.xserver.xkb defined in localization.nix — already
      # propagated via XKB_DEFAULT_LAYOUT, set explicitly here for robustness.
      input.keyboard = {
        layout = "br";
        variant = "abnt2";
      };

      keybinds = {
        "Mod+Return" = "spawn:ghostty";
        "Mod+Shift+Q" = "window-close";
        # Opens Noctalia's app launcher (replaces the GNOME Shell overview).
        "Mod" = "spawn:noctalia msg panel-toggle launcher";
        # Generic scratchpad, used below for the quake-style Ghostty drop-down
        # (replaces the quake-terminal GNOME Shell extension).
        "Mod+Space" = "scratchpad-toggle";
        "Mod+Shift+Space" = "window-move-to-scratchpad";
        "F12" =
          "spawn:ghostty --window-decoration=false --gtk-single-instance=false --class=com.mitchellh.ghostty.quake";
      };

      # Floats the quake-style Ghostty window instead of tiling it. Move it to
      # the scratchpad once (Mod+Shift+Space) after the first F12 spawn; Mod+Space
      # toggles it from then on.
      window_rule = [
        {
          match.app_id = "^com.mitchellh.ghostty.quake$";
          default_floating = true;
          default_size = [
            1200
            500
          ];
        }
      ];
    };
  };

  # ── Shell: Noctalia ────────────────────────────────────────────────────
  programs.noctalia = {
    enable = true;
    settings = {
      shell = {
        # Noctalia's own polkit agent — no separate agent package needed.
        polkit_agent = true;
      };

      theme = {
        mode = "dark";
        source = "builtin";
        # Matches the Catppuccin Mocha palette used elsewhere (starship, greeter).
        builtin = "Catppuccin";
      };

      dock = {
        enabled = true;
        pinned = [
          "org.mozilla.firefox"
          "com.brave.Browser"
          "code"
          "dev.zed.Zed"
        ];
      };
    };
  };
}
