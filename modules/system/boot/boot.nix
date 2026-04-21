# Módulo de boot: systemd-boot + Plymouth para experiência flicker-free
{ lib, ... }:

{
  boot = {
    # systemd-boot como gerenciador de boot padrão
    # Nota: No host barbudus, o lanzaboote substitui o systemd-boot para Secure Boot
    loader = {
      systemd-boot = {
        enable = lib.mkDefault true;
        configurationLimit = 10;
        editor = false; # Desabilita editor de boot (segurança)
      };
      efi.canTouchEfiVariables = true;
      timeout = 3;
    };

    # Plymouth para splash screen durante o boot
    plymouth = {
      enable = true;
      theme = lib.mkDefault "spinner";
    };

    # Parâmetros do kernel para boot silencioso/flicker-free
    kernelParams = [
      "quiet"
      "splash"
      "loglevel=3"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
      # Desabilita mensagens de boot no framebuffer
      "vt.global_cursor_default=0"
    ];

    # Suprimir mensagens do kernel no console durante boot
    consoleLogLevel = 0;

    # Initrd silencioso
    initrd.verbose = false;
  };

  # Configuração do framebuffer para evitar flickering
  # (KMS/DRM mantém resolução do boot ao carregar driver)
  # Os módulos KMS específicos (i915, nvidia, etc.) são definidos em cada host
  # via boot.initrd.kernelModules nas hardware-configuration.nix
}
