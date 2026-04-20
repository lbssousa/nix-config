# Módulo comum: Configurações básicas do sistema NixOS
_:

{
  # Permitir pacotes proprietários (necessário para drivers NVIDIA, etc.)
  nixpkgs.config.allowUnfree = true;

  # Suporte ao ZFS
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.forceImportRoot = false;

  # ID único do host para ZFS (deve ser único na rede)
  # Gere com: head -c 8 /dev/urandom | od -A n -t x1 | tr -d ' \n'
  # networking.hostId é definido em cada host

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
  };

  # Configuração do teclado X11
  services.xserver.xkb = {
    layout = "br";
    variant = "";
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

  # Serviços ZFS
  services.zfs = {
    autoScrub.enable = true;
    autoScrub.interval = "monthly";
    trim.enable = true;
  };

  # Versão do estado do sistema
  system.stateVersion = "25.05";
}
