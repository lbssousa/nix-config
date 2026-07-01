# Módulo de boot: systemd-boot + Plymouth para experiência flicker-free
{ lib, pkgs, ... }:

{
  boot = {
    # Kernel Linux mais recente (não-LTS)
    kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;
    # systemd-boot como gerenciador de boot padrão
    # Nota: No host barbudus, o lanzaboote substitui o systemd-boot para Secure Boot
    loader = {
      systemd-boot = {
        enable = lib.mkDefault true;
        configurationLimit = 10;
        editor = false; # Desabilita editor de boot (segurança)
        # Mantém resolução máxima no menu de boot, evitando flickering
        consoleMode = lib.mkDefault "max";
      };
      efi.canTouchEfiVariables = true;
      # timeout = 0: oculta o menu e inicia a entrada padrão imediatamente,
      # evitando o flicker causado pela exibição do menu durante o boot.
      # Para exibir o menu manualmente, mantenha pressionada a tecla Space (ou qualquer
      # tecla) imediatamente após a tela do firmware UEFI, durante a janela de boot.
      # Para alterar temporariamente via terminal: sudo bootctl set-timeout <segundos>
      timeout = 0;
    };

    # Plymouth para splash screen durante o boot
    plymouth = {
      enable = true;
      # bgrt: usa o logotipo OEM do firmware (ACPI BGRT) para transição suave
      # firmware → bootloader → Plymouth sem flickering
      theme = lib.mkDefault "bgrt";
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
