# Localization module: language, timezone and keyboard
_:

{
  # Keeps the TTY aligned with the system's XKB config.
  console.useXkbConfig = true;

  # Needed even on Wayland: IBus follows the system's XKB layout.
  # Without this, localectl reports X11 Layout: us and IBus falls back to
  # English on relogin.
  services.xserver.xkb = {
    layout = "br";
    variant = "abnt2";
    model = "abnt2";
  };

  # CapsLock remapping via kanata (evdev level, works in TTY and Wayland):
  #   single tap    → Esc
  #   hold          → Ctrl
  #   Shift + tap   → CapsLock
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
