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
  imports = [
    ../../modules/system/core/common.nix
    ../../modules/system/core/impermanence.nix
    ../../modules/system/audio/audio.nix
    ../../modules/system/boot/boot.nix
    ../../modules/system/containers/containers.nix
    ../../modules/system/desktop/desktop.nix
    ../../modules/system/hardware/printing.nix
    ../../modules/system/network/ssh.nix
    ../../modules/system/security/tpm2.nix
    ../../modules/system/shell/shells.nix
    ../../modules/system/tools/homebrew.nix
    ../../modules/system/tools/packages.nix
    ../../modules/system/users/users.nix
    # Carregar configurações de usuário (não commitadas - ver .gitignore)
    # Descomente e ajuste conforme necessário:
    # ./../../users/seu-usuario.nix
  ];

  # Nome do host
  networking.hostName = "barbudus";

  # --- Drivers NVIDIA (proprietary) ---
  # GeForce MX230 com PRIME offload (Intel integrada + NVIDIA discreta)

  # Habilitar suporte OpenGL/Vulkan
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Driver NVIDIA proprietary
  hardware.nvidia = {
    # Usar driver estável (580.x para NixOS unstable)
    package = config.boot.kernelPackages.nvidiaPackages.stable;
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
    # Módulo de vídeo NVIDIA (KMS/Wayland)
    xserver.videoDrivers = [ "nvidia" ];

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
  ];

  # Preservar configurações de Secure Boot em /persist
  environment.persistence."/persist".directories = [ "/etc/secureboot" ];
}
