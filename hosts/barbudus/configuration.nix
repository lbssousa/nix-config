# Configuração principal para barbudus (Dell Inspiron 14 5490)
# Hardware: Intel i5-10210U, 16 GB RAM, Intel UHD 620 + NVIDIA GeForce MX230
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Scripts goodix-fp-dump para diagnóstico do sensor de impressão digital
  goodix-fp-dump = pkgs.stdenv.mkDerivation {
    pname = "goodix-fp-dump";
    version = "unstable";
    src = pkgs.fetchFromGitHub {
      owner = "goodix-fp-linux-dev";
      repo = "goodix-fp-dump";
      rev = "master";
      hash = "sha256-JqY0kRMm//xsmcpGOkUjUD/WNqTZM8oKGNxir/Hkyfg=";
    };
    # Dependências Python do requirements.txt
    nativeBuildInputs = with pkgs; [ makeWrapper ];
    buildInputs = with pkgs.python3Packages; [
      pyusb
      cryptography
      construct
      pillow
    ];
    installPhase = ''
      mkdir -p $out/share/goodix-fp-dump
      cp -r . $out/share/goodix-fp-dump/
      chmod +x $out/share/goodix-fp-dump/*.py 2>/dev/null || true
    '';
  };
in
{
  # Nome do host
  networking.hostName = "barbudus";

  # --- Drivers NVIDIA (proprietary) ---
  # GeForce MX230 com PRIME offload (Intel integrada + NVIDIA discreta)
  #
  # COMO USAR A GPU DEDICADA:
  # - Terminal: nvidia-offload <app>  (ex: nvidia-offload blender)
  # - Helper: run-with-nvidia <app>   (alias com melhor UX)
  # - Verificar: glxinfo | grep "NVIDIA" ou nvidia-smi

  # Habilitar suporte OpenGL/Vulkan e VA-API
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-media-driver # iHD driver para Intel UHD 620 (Comet Lake)
      intel-vaapi-driver # i965 driver (fallback para conteúdo legado)
      nvidia-vaapi-driver # VA-API via NVDEC para GeForce MX230
    ];
  };

  # Forçar iHD como driver VA-API padrão (evita que o i965 seja escolhido
  # automaticamente, o que limitaria os formatos suportados)
  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";

  # Driver NVIDIA proprietary
  hardware.nvidia = {
    # Forçar versão 580.x (stable = 595.x é incompatível com GeForce MX230)
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
    modesetting.enable = true;
    open = false; # MX230 é GPU antiga, usar driver proprietário (não o open-source)
    powerManagement = {
      enable = true;
      finegrained = true; # Desligar GPU NVIDIA quando não usada (economia de bateria)
    };
    prime = {
      # IDs de barramento PCI (verifique com: lspci | grep -E "VGA|3D")
      # Exemplo: 00:02.0 = Intel, 01:00.0 = NVIDIA
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
      # PRIME offload: usa Intel por padrão, NVIDIA sob demanda
      offload = {
        enable = true;
        enableOffloadCmd = true; # Habilita comando 'nvidia-offload'
      };
    };
  };

  # --- Fingerprint (sensor Goodix) ---
  # fprintd com suporte ao sensor Goodix (fork do infinytum/libfprint)
  services = {

    # switcheroo-control: expõe GPUs via D-Bus (para GNOME e outras ferramentas)
    switcherooControl.enable = true;

    fprintd = {
      enable = true;
      # NOTA: Depois de resolver o hash do libfprint-goodix acima,
      # descomente as linhas abaixo para usar o fork personalizado:
      # tod.enable = true;
    };

    # --- Configurações de energia para laptop ---
    power-profiles-daemon.enable = true;
    thermald.enable = true; # Gerenciamento térmico Intel
  };

  # --- Secure Boot com Lanzaboote ---
  # Para Secure Boot com NVIDIA (assina módulos do kernel)
  # NOTA: Requer configuração inicial de chaves (ver INSTALLATION.md)
  boot.loader.systemd-boot.enable = lib.mkForce false; # Substituído pelo lanzaboote
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/persist/etc/secureboot"; # Chaves armazenadas em /persist
  };

  # Scripts goodix-fp-dump para desenvolvimento/diagnóstico
  environment.systemPackages = [
    goodix-fp-dump
    # Dependências Python para os scripts
    (pkgs.python3.withPackages (
      ps: with ps; [
        pyusb
        cryptography
        construct
        pillow
      ]
    ))
    # sbctl é necessário para gerenciar chaves Secure Boot com lanzaboote.
    # Adicionado explicitamente para garantir disponibilidade independente do que
    # o módulo lanzaboote injeta em systemPackages.
    pkgs.sbctl

    # Script helper para executar aplicações com nvidia-offload
    (pkgs.writeScriptBin "run-with-nvidia" ''
      #!/usr/bin/env bash
      # Helper para executar aplicações com GPU NVIDIA dedicada
      # Uso: run-with-nvidia <comando> [args...]
      if [[ -z "$1" ]]; then
        echo "Uso: run-with-nvidia <comando> [args...]"
        echo "Exemplo: run-with-nvidia glxinfo"
        echo "         run-with-nvidia blender"
        exit 1
      fi
      nvidia-offload "$@"
    '')
  ];

  # Criar symlink /var/lib/sbctl → /persist/etc/secureboot a cada boot.
  # Necessário porque a raiz (/) é tmpfs e é apagada a cada reinicialização.
  # O módulo lanzaboote (v0.4.1) NÃO cria este symlink automaticamente;
  # é responsabilidade da configuração do host criá-lo via systemd-tmpfiles.
  # Sem este symlink, o sbctl não consegue localizar o banco de chaves PKI
  # e o setup-secureboot.sh falha na verificação do banco de chaves.
  systemd.tmpfiles.rules = [
    "L+ /var/lib/sbctl - - - - /persist/etc/secureboot"
  ];
}
