# Configuração do tmux baseada nas predefinições do Omarchy
# (https://github.com/basecamp/omarchy), com integração ao neovim
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
    # sensibleOnTop = true (padrão): aplica tmux-sensible antes das demais opções

    plugins = with pkgs.tmuxPlugins; [
      # Navegação sem costuras entre painéis tmux e splits neovim (C-h/j/k/l/\)
      vim-tmux-navigator
      # Copiar para clipboard do sistema no modo vi (wl-copy no Wayland)
      yank
    ];

    extraConfig = ''
      # Prefixo secundário e envio do prefixo
      set -g prefix2 C-b
      bind C-Space send-prefix

      # Cores verdadeiras (true color) — essencial para o tema TokyoNight do neovim
      set -ag terminal-overrides ",*:RGB"
      set -ag terminal-overrides ",xterm-256color:RGB"

      # Undercurl (sublinhado ondulado) — diagnósticos LSP no neovim
      set -as terminal-overrides ',*:Smulx=\E[4::%p1%dm'

      # Teclas estendidas no formato CSI-u — suporte completo ao teclado
      set -g extended-keys on
      set -g extended-keys-format csi-u

      # Eventos de foco — necessários para FocusGained/FocusLost no neovim
      set -g focus-events on

      # Área de transferência e passagem direta de sequências de escape
      set -g set-clipboard on
      set -g allow-passthrough on

      # Ao fechar a última janela da sessão, alternar para a sessão anterior
      set -g detach-on-destroy off

      # Redimensionar baseado no cliente ativo (não no maior conectado)
      setw -g aggressive-resize on

      # Painéis numerados a partir de 1 (consistente com baseIndex)
      setw -g pane-base-index 1

      # Renumerar janelas ao fechar uma delas
      set -g renumber-windows on

      # Controles de painel
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

      # Navegação de janelas
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

      # Controles de sessão
      bind R command-prompt -I "#S" "rename-session -- '%%'"
      bind C new-session -c "#{pane_current_path}"
      bind K kill-session
      bind P switch-client -p
      bind N switch-client -n

      bind -n M-Up switch-client -p
      bind -n M-Down switch-client -n

      # Modo vi: seleção retangular (y e v tratados pelo plugin yank)
      bind-key -T copy-mode-vi v send-keys -X begin-selection
      bind-key -T copy-mode-vi C-v send-keys -X rectangle-toggle

      # Recarregar configuração
      bind q source-file ~/.config/tmux/tmux.conf \; display "Configuração recarregada!"

      # Barra de status no topo
      set -g status-position top
      set -g status-interval 5
      set -g status-left-length 30
      set -g status-right-length 50
      set -g window-status-separator ""
      set -gw automatic-rename on
      set -gw automatic-rename-format "#{b:pane_current_path}"

      # Tema (Omarchy — azul)
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
