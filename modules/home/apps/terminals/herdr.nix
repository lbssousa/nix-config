# herdr — agent multiplexer that lives in your terminal (https://herdr.dev)
_: {
  programs.herdr = {
    enable = true;

    settings = {
      theme = {
        name = "catppuccin";
        auto_switch = true;
        light_name = "catppuccin-latte";
        dark_name = "catppuccin";
      };

      keys = {
        # Mirrors the tmux prefix (tmux.nix) — same muscle memory, and
        # Ghostty already disambiguates it from ctrl+@/ctrl+2 via the
        # kitty keyboard protocol, which herdr's vendored libghostty-vt
        # also speaks.
        prefix = "ctrl+space";

        # Pane navigation without a prefix, matching vim-tmux-navigator.
        focus_pane_left = "ctrl+h";
        focus_pane_down = "ctrl+j";
        focus_pane_up = "ctrl+k";
        focus_pane_right = "ctrl+l";
      };

      keys.command = [
        {
          key = "g";
          type = "pane";
          command = "lazygit";
          description = "lazygit";
        }
      ];
    };
  };
}
