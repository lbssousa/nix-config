# Configuração principal para barbudus (Dell Inspiron 14 5490)
# Hardware: Intel i5-10210U, 16 GB RAM, Intel UHD 620 + NVIDIA GeForce MX230
{ config, lib, pkgs, inputs, ... }:

let
  # Pacote personalizado do libfprint com suporte ao sensor Goodix
  # Fork do projeto https://github.com/infinytum/libfprint (branch unstable)
  libfprint-goodix = pkgs.libfprint.overrideAttrs (oldAttrs: {
    pname = "libfprint-goodix";
    version = "unstable-2024";
    src = pkgs.fetchFromGitHub {
      owner = "infinytum";
      repo = "libfprint";
      rev = "unstable"; # Branch unstable do fork
      # NOTA: Atualize o hash abaixo com:
      # nix-prefetch-github infinytum libfprint --rev unstable
      sha256 = lib.fakeSha256; # SUBSTITUA pelo hash real
    };
  });

  # Scripts goodix-fp-dump para diagnóstico do sensor de impressão digital
  goodix-fp-dump = pkgs.stdenv.mkDerivation {
    pname = "goodix-fp-dump";
    version = "unstable";
    src = pkgs.fetchFromGitHub {
      owner = "goodix-fp-linux-dev";
      repo = "goodix-fp-dump";
      rev = "main";
      # NOTA: Atualize o hash abaixo com:
      # nix-prefetch-github goodix-fp-linux-dev goodix-fp-dump --rev main
      sha256 = lib.fakeSha256; # SUBSTITUA pelo hash real
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
    ../../modules/common.nix
    ../../modules/audio.nix
    ../../modules/boot.nix
    ../../modules/containers.nix
    ../../modules/desktop.nix
    ../../modules/homebrew.nix
    ../../modules/impermanence.nix
    ../../modules/packages.nix
    ../../modules/printing.nix
    ../../modules/shells.nix
    ../../modules/ssh.nix
    ../../modules/users.nix
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

  # Módulo de vídeo NVIDIA para X11
  services.xserver.videoDrivers = [ "nvidia" ];

  # --- Secure Boot com Lanzaboote ---
  # Para Secure Boot com NVIDIA (assina módulos do kernel)
  # NOTA: Requer configuração inicial de chaves (ver INSTALLATION.md)
  boot.loader.systemd-boot.enable = lib.mkForce false; # Substituído pelo lanzaboote
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/persist/etc/secureboot"; # Chaves armazenadas em /persist
  };

  # --- Fingerprint (sensor Goodix) ---
  # fprintd com suporte ao sensor Goodix (fork do infinytum/libfprint)
  services.fprintd = {
    enable = true;
    # NOTA: Depois de resolver o hash do libfprint-goodix acima,
    # descomente a linha abaixo para usar o fork personalizado:
    # tod.enable = true;
    # tod.driver = libfprint-goodix;
  };

  # Scripts goodix-fp-dump para desenvolvimento/diagnóstico
  environment.systemPackages = [
    goodix-fp-dump
    # Dependências Python para os scripts
    (pkgs.python3.withPackages (ps: with ps; [
      pyusb
      cryptography
      construct
      pillow
    ]))
  ];

  # --- Configurações de energia para laptop ---
  services.power-profiles-daemon.enable = true;
  services.thermald.enable = true; # Gerenciamento térmico Intel

  # Preservar configurações de Secure Boot em /persist
  environment.persistence."/persist".directories = [
    "/etc/secureboot"
  ];
}
