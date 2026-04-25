# Módulo comum: Configurações básicas do sistema NixOS
_:

{
  # Permitir pacotes proprietários (necessário para drivers NVIDIA, etc.)
  nixpkgs.config.allowUnfree = true;

  # Suporte ao Btrfs (garante ferramentas e módulo de kernel disponíveis)
  boot.supportedFilesystems = [ "btrfs" ];

  # Rede
  networking.networkmanager.enable = true;

  # Localização e teclado
  console.keyMap = "br-abnt2";
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
    # ibus como método de entrada: o daemon ibus intercepta as teclas mortas (dead_tilde,
    # dead_acute, etc.) e entrega apenas o caractere composto final à aplicação.
    # Isso corrige o bug do VTE/Ptyxis no Wayland, onde dead keys ficavam "penduradas"
    # ao pressionar Enter (impedindo o uso de ~ como atalho de diretório), sem sacrificar
    # a ergonomia: acentos continuam a funcionar com 2 teclas (´ + a = á, ~ + a = ã, etc.)
    # e o AltGr continua funcional para [ ] { } | etc.
    inputMethod = {
      enable = true;
      type = "ibus";
    };
  };

  # Configuração do teclado X11/Wayland — layout ABNT2 padrão com dead keys
  services.xserver.xkb = {
    layout = "br";
    variant = "abnt2";
    model = "abnt2";
  };

  # Configurações do Nix
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
      # Cache binário oficial e community
      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCUSeBs="
      ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  # Versão do estado do sistema
  system.stateVersion = "25.05";
}
