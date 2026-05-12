# Módulo comum: Configurações básicas do sistema NixOS
_:

{
  imports = [
    ./localization.nix
  ];

  # Permitir pacotes proprietários (necessário para drivers NVIDIA, etc.)
  nixpkgs.config.allowUnfree = true;

  # Suporte ao Btrfs (garante ferramentas e módulo de kernel disponíveis)
  boot.supportedFilesystems = [ "btrfs" ];

  # Rede
  networking.networkmanager.enable = true;

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

  # Repassa o socket do agente SSH ao processo sudo.
  # Mantido para compatibilidade com scripts (ex.: setup-secureboot.sh,
  # enroll-tpm2.sh) que ainda usam `sudo -E`. O uso interativo preferencial
  # é run0 com --setenv=SSH_AUTH_SOCK (ver aliases nrs/nru/nrb em home/).
  security.sudo.extraConfig = ''
    Defaults:%wheel env_keep+=SSH_AUTH_SOCK
  '';

  # Versão do estado do sistema
  system.stateVersion = "25.05";
}
