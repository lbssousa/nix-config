{ pkgs, ... }:
{
  programs.keepassxc = {
    enable = true;

    # O plugin qgnomeplatform 0.8.4 (QT_WAYLAND_DECORATION=gnome, padrão do
    # sistema) define as cores da decoração uma única vez no construtor e não
    # monitora mudanças em org.gnome.desktop.interface.color-scheme. Por isso a
    # barra de título fica presa no modo escuro ou claro definido na
    # inicialização, mesmo que o GNOME alterne entre os modos em seguida.
    #
    # O plugin qadwaitadecorations (QT_WAYLAND_DECORATION=adwaita) assina o
    # sinal SettingChanged do org.freedesktop.portal.Settings e chama
    # updateColors() + forceRepaint() a cada alteração de color-scheme,
    # mantendo a decoração sincronizada com o modo do sistema.
    package = pkgs.symlinkJoin {
      name = "keepassxc";
      paths = [ pkgs.keepassxc ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/keepassxc \
          --set QT_WAYLAND_DECORATION adwaita
      '';
    };
  };
}
