# Common module: basic NixOS system settings
_:

{
  imports = [
    ./localization.nix
  ];

  # Allow proprietary packages (needed for NVIDIA drivers, etc.)
  nixpkgs.config.allowUnfree = true;

  # Btrfs support (ensures tools and kernel module are available)
  boot.supportedFilesystems = [ "btrfs" ];

  # Networking
  networking.networkmanager.enable = true;

  # Nix settings
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
      # Official and community binary caches
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

  # Passes the SSH agent socket through to the sudo process.
  # Kept for compatibility with scripts (e.g. setup-secureboot.sh,
  # enroll-tpm2.sh) that still use `sudo -E`. The preferred interactive use
  # is run0 with --setenv=SSH_AUTH_SOCK (see the nrs/nru/nrb aliases in home/).
  security.sudo.extraConfig = ''
    Defaults:%wheel env_keep+=SSH_AUTH_SOCK
  '';

  # System state version
  system.stateVersion = "25.05";
}
