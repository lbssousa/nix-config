{ pkgs, ... }:
{
  programs.keepassxc = {
    enable = true;

    # Três sobreposições de ambiente são necessárias para integração correta com GNOME:
    #
    # 1. QT_WAYLAND_DECORATION=adwaita
    #    O plugin qgnomeplatform 0.8.4 (padrão do sistema via QT_WAYLAND_DECORATION=gnome)
    #    define as cores da decoração uma única vez no construtor e não monitora
    #    mudanças em org.gnome.desktop.interface.color-scheme. O plugin qadwaitadecorations
    #    assina o sinal SettingChanged do org.freedesktop.portal.Settings e chama
    #    updateColors() + forceRepaint() a cada alteração, mantendo a barra de título
    #    sincronizada com o modo claro/escuro do sistema.
    #
    # 2. QT_PLUGIN_PATH prefixado com qadwaitadecorations
    #    qadwaitadecorations não é dependência de build do keepassxc no nixpkgs,
    #    então seu diretório não entra no QT_PLUGIN_PATH gerado pelo wrapper Qt.
    #    Precisamos incluí-lo explicitamente para que o Qt encontre o plugin.
    #
    # 3. QT_QPA_PLATFORMTHEME=xdgdesktopportal
    #    O tema "gnome" (qgnomeplatform, padrão do sistema) abre diálogos de arquivo
    #    como widgets GTK3 dentro do processo do KeePassXC. Isso causa dois problemas:
    #    (a) gtk-application-prefer-dark-theme no settings.ini força modo escuro
    #        independentemente do color-scheme atual do GNOME;
    #    (b) ao alternar claro/escuro enquanto o diálogo está aberto, o GTK3
    #        recarrega o tema via inotify e a renderização ativa causa segfault.
    #    Com xdgdesktopportal, o diálogo de arquivo é delegado ao portal GNOME,
    #    que roda em processo separado e sempre reflete o modo correto do sistema.
    #    Para fontes, cursor e demais integrações, xdgdesktopportal delega ao
    #    tema subjacente "gnome" (determinado por XDG_CURRENT_DESKTOP=GNOME).
    package = pkgs.symlinkJoin {
      name = "keepassxc";
      paths = [ pkgs.keepassxc ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/keepassxc \
          --set QT_WAYLAND_DECORATION adwaita \
          --prefix QT_PLUGIN_PATH : ${pkgs.qadwaitadecorations}/lib/qt-${pkgs.qt5.qtbase.version}/plugins \
          --set QT_QPA_PLATFORMTHEME xdgdesktopportal
      '';
    };
  };
}
