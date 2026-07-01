# Módulo de localização: idioma, fuso horário e teclado
_:

{
  # Mantém o TTY alinhado com o XKB do sistema.
  console.useXkbConfig = true;

  # Necessário mesmo em Wayland: o IBus segue o layout XKB de sistema.
  # Sem isso, localectl reporta X11 Layout: us e o IBus cai para inglês no relogin.
  services.xserver.xkb = {
    layout = "br";
    variant = "abnt2";
    model = "abnt2";
  };

  # Remapeamento do CapsLock via kanata (nível evdev, funciona em TTY e Wayland):
  #   toque simples       → Esc
  #   manter pressionado  → Ctrl
  #   Shift + toque       → CapsLock
  services.kanata = {
    enable = true;
    keyboards.default = {
      extraDefCfg = "process-unmapped-keys yes";
      config = ''
        (defsrc
          caps
        )

        (defalias
          caps (fork
            (tap-hold-press 200 200 esc lctrl)
            (tap-hold-press 200 200 caps lctrl)
            (lsft rsft))
        )

        (deflayer base
          @caps
        )
      '';
    };
  };

  time.timeZone = "America/Sao_Paulo";

  i18n = {
    defaultLocale = "pt_BR.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "pt_BR.UTF-8";
      LC_IDENTIFICATION = "pt_BR.UTF-8";
      LC_MEASUREMENT = "pt_BR.UTF-8";
      LC_MONETARY = "pt_BR.UTF-8";
      LC_NAME = "pt_BR.UTF-8";
      LC_NUMERIC = "pt_BR.UTF-8";
      LC_PAPER = "pt_BR.UTF-8";
      LC_TELEPHONE = "pt_BR.UTF-8";
      LC_TIME = "pt_BR.UTF-8";
    };
  };
}
