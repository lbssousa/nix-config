# Configuração do Ghostty para uso com a extensão quake-terminal do GNOME
_:

{
  xdg.configFile."ghostty/config".text = ''
    # Fonte
    font-family = JetBrainsMono Nerd Font Mono
    font-size = 14

    # Remove decorações de janela — o quake-terminal gerencia
    # posicionamento, tamanho e visibilidade da janela
    window-decoration = false

    # Abas na parte inferior: mais visíveis quando a janela cai do topo
    gtk-tabs-location = bottom

    # Fechar automaticamente ao fechar a última janela
    quit-after-last-window-closed = true

    # Sem confirmação ao fechar abas — o quake-terminal pode ocultar/fechar
    # a janela a qualquer momento
    confirm-close-surface = false

    # Opacidade da janela (80%)
    background-opacity = 0.8

    # Paleta GNOME (padrão do Ptyxis) — tema escuro
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
    palette = 10=#33DA7A
    palette = 11=#E9AD0C
    palette = 12=#2A7BDE
    palette = 13=#C061CD
    palette = 14=#33C7DE
    palette = 15=#FFFFFF

    # Negritos usam as cores brilhantes da paleta (índices 8–15)
    bold-color = bright

    # Sinal sonoro do sistema para notificações
    bell-features = system

    # Desabilitar auto-atualização (pacote gerenciado pelo Nix)
    auto-update = off
  '';
}
