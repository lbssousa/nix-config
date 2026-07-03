# Configuração do Ghostty — terminal padrão do desktop
#
# Para abrir sem decorações (PaperWM, quake-terminal):
#   ghostty --window-decoration=false
#
# O desktop entry 'com.mitchellh.ghostty.quake' (oculto do menu de apps) é usado
# pela extensão quake-terminal via terminal-id. O flag --class define o GApplication
# ID (e portanto o app_id Wayland), que o GNOME Shell usa para atribuir janelas ao
# Shell.App correto — sem isso, o Shell atribui a janela a com.mitchellh.ghostty.desktop
# e o sinal windows-changed nunca dispara para o app monitorado pela extensão.
#
# Nota: Ghostty 1.3.1 não suporta [profile:name] no config — usa-se as flags
# diretamente na linha de comando.
_:

{
  xdg = {
    configFile."ghostty/config".text = ''
      # ── Fonte ──────────────────────────────────────────────────────────────
      font-family = JetBrainsMono Nerd Font
      font-size = 14

      # ── Aparência ──────────────────────────────────────────────────────────
      # Perfil padrão: decorações ativas para uso normal
      window-decoration = true

      # Abas na parte inferior: mais visíveis quando a janela cai do topo
      gtk-tabs-location = bottom

      # Opacidade da janela (90%)
      background-opacity = 0.90

      # Paleta GNOME (tema escuro — compatível com o padrão do Ptyxis)
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

      # Negritos usam as cores brilhantes da paleta (índices 8–15)
      bold-color = bright

      # ── Comportamento ──────────────────────────────────────────────────────
      quit-after-last-window-closed = true
      confirm-close-surface = false
      bell-features = system

      # Desabilitar auto-atualização (pacote gerenciado pelo Nix)
      auto-update = off
    '';

    # Desktop entry oculto do menu de apps, usado pela extensão quake-terminal.
    # --class: define o GApplication ID como com.mitchellh.ghostty.quake, o que
    #   faz o GNOME Shell atribuir a janela a este desktop entry (via app_id Wayland),
    #   permitindo que o sinal windows-changed dispare no Shell.App correto.
    # --gtk-single-instance=false: impede que esta instância se registre como
    #   singleton GApplication. Sem isso, ela capturaria o slot de instância única
    #   e janelas abertas normalmente seriam roteadas para este processo.
    desktopEntries."com.mitchellh.ghostty.quake" = {
      name = "Ghostty (Quake)";
      exec = "ghostty --window-decoration=false --gtk-single-instance=false --class=com.mitchellh.ghostty.quake";
      icon = "com.mitchellh.ghostty";
      noDisplay = true;
    };
  };
}
