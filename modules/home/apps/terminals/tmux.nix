# tmux configuration based on Omarchy's defaults
# (https://github.com/basecamp/omarchy), with neovim integration
# via vim-tmux-navigator (C-h/j/k/l).
{ pkgs, ... }:

{
  programs.tmux = {
    enable = true;
    prefix = "C-Space";
    baseIndex = 1;
    escapeTime = 10;
    historyLimit = 50000;
    keyMode = "vi";
    mouse = true;
    terminal = "tmux-256color";
    # sensibleOnTop = true (default): applies tmux-sensible before other options

    plugins = with pkgs.tmuxPlugins; [
      # Seamless navigation between tmux panes and neovim splits (C-h/j/k/l/\)
      vim-tmux-navigator
      # Copy to system clipboard in vi mode (wl-copy on Wayland)
      yank
    ];

    extraConfig = ''
      # Secondary prefix and prefix passthrough
      set -g prefix2 C-b
      bind C-Space send-prefix

      # True color — essential for neovim's TokyoNight theme
      set -ag terminal-overrides ",*:RGB"
      set -ag terminal-overrides ",xterm-256color:RGB"

      # Undercurl (wavy underline) — LSP diagnostics in neovim
      set -as terminal-overrides ',*:Smulx=\E[4::%p1%dm'

      # Extended keys in CSI-u format — full keyboard support
      set -g extended-keys on
      set -g extended-keys-format csi-u

      # Focus events — needed for FocusGained/FocusLost in neovim
      set -g focus-events on

      # Clipboard and passthrough of escape sequences
      set -g set-clipboard on
      set -g allow-passthrough on

      # When closing the session's last window, switch to the previous session
      set -g detach-on-destroy off

      # Resize based on the active client (not the largest connected one)
      setw -g aggressive-resize on

      # Panes numbered starting at 1 (consistent with baseIndex)
      setw -g pane-base-index 1

      # Renumber windows when one is closed
      set -g renumber-windows on

      # Pane controls
      bind -n M-Enter split-window -v -c "#{pane_current_path}"
      bind -n M-S-Enter split-window -h -c "#{pane_current_path}"
      bind -n M-Escape kill-pane

      bind h split-window -v -c "#{pane_current_path}"
      bind v split-window -h -c "#{pane_current_path}"
      bind x kill-pane

      bind -n C-M-Left select-pane -L
      bind -n C-M-Right select-pane -R
      bind -n C-M-Up select-pane -U
      bind -n C-M-Down select-pane -D

      bind -n C-M-S-Left resize-pane -L 5
      bind -n C-M-S-Down resize-pane -D 5
      bind -n C-M-S-Up resize-pane -U 5
      bind -n C-M-S-Right resize-pane -R 5

      # Window navigation
      bind r command-prompt -I "#W" "rename-window -- '%%'"
      bind c new-window -c "#{pane_current_path}"
      bind k kill-window

      bind -n M-1 select-window -t 1
      bind -n M-2 select-window -t 2
      bind -n M-3 select-window -t 3
      bind -n M-4 select-window -t 4
      bind -n M-5 select-window -t 5
      bind -n M-6 select-window -t 6
      bind -n M-7 select-window -t 7
      bind -n M-8 select-window -t 8
      bind -n M-9 select-window -t 9

      bind -n M-Left select-window -t -1
      bind -n M-Right select-window -t +1
      bind -n M-S-Left swap-window -t -1 \; select-window -t -1
      bind -n M-S-Right swap-window -t +1 \; select-window -t +1

      # Session controls
      bind R command-prompt -I "#S" "rename-session -- '%%'"
      bind C new-session -c "#{pane_current_path}"
      bind K kill-session
      bind P switch-client -p
      bind N switch-client -n

      bind -n M-Up switch-client -p
      bind -n M-Down switch-client -n

      # vi mode: rectangle selection (y and v handled by the yank plugin)
      bind-key -T copy-mode-vi v send-keys -X begin-selection
      bind-key -T copy-mode-vi C-v send-keys -X rectangle-toggle

      # Reload configuration
      bind q source-file ~/.config/tmux/tmux.conf \; display "Configuration reloaded!"

      # Status bar at the top
      set -g status-position top
      set -g status-interval 5
      set -g status-left-length 30
      set -g status-right-length 50
      set -g window-status-separator ""
      set -gw automatic-rename on
      set -gw automatic-rename-format "#{b:pane_current_path}"

      # Theme (Omarchy — blue)
      set -g status-style "bg=default,fg=default"
      set -g status-left "#[fg=black,bg=blue,bold] #S #[bg=default] "
      set -g status-right "#[fg=blue]#{?pane_in_mode,COPY ,}#{?client_prefix,PREFIX ,}#{?window_zoomed_flag,ZOOM ,}#[fg=brightblack]#h "
      set -g window-status-format "#[fg=brightblack] #I:#W "
      set -g window-status-current-format "#[fg=blue,bold] #I:#W "
      set -g pane-border-style "fg=brightblack"
      set -g pane-active-border-style "fg=blue"
      set -g message-style "bg=default,fg=blue"
      set -g message-command-style "bg=default,fg=blue"
      set -g mode-style "bg=blue,fg=black"
      setw -g clock-mode-colour blue
    '';
  };
}
