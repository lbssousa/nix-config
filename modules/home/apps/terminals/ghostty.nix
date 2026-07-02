# Configuração do Ghostty — terminal padrão do desktop
#
# Perfis disponíveis:
#   padrão         → decorações de janela ativas (uso normal, clique duplo na barra,
#                    redimensionamento nativo)
#   no-decorations → sem decorações (PaperWM, quake-terminal)
#
# Para abrir o perfil sem decorações:
#   ghostty --profile=no-decorations
#
# O desktop entry 'ghostty-no-decorations' (oculto do menu de apps) é criado em
# ~/.local/share/applications/ para que a extensão quake-terminal possa lançar
# Ghostty diretamente neste perfil via terminal-id.
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

      # ── Perfil: sem decorações ─────────────────────────────────────────────
      # Uso direto: ghostty --profile=no-decorations
      # Quake-terminal: configurado via terminal-id = ghostty-no-decorations.desktop
      # PaperWM: abrir manualmente com o comando acima ou via atalho customizado
      [profile:no-decorations]
      window-decoration = false
    '';

    # Desktop entry oculto do menu de apps, usado pela extensão quake-terminal
    # para lançar Ghostty já no perfil sem decorações.
    # --gtk-single-instance=false: impede que esta instância se registre como
    # singleton GApplication. Sem isso, ela capturaria o slot de instância única
    # e janelas abertas "explicitamente" (com --gtk-single-instance=true) seriam
    # roteadas para este processo, herdando o perfil sem decorações.
    desktopEntries."ghostty-no-decorations" = {
      name = "Ghostty (sem decorações)";
      exec = "ghostty --profile=no-decorations --gtk-single-instance=false";
      icon = "com.mitchellh.ghostty";
      noDisplay = true;
    };
  };
}
