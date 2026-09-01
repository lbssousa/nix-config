{ config, inputs, ... }:
let
  mkUserModule = username: ../../users + "/${username}.nix";
in
{
  config.dendritic.nixos = {
    sharedModules = [
      ../../modules/system/core/common.nix
      ../../modules/system/core/preservation.nix
      ../../modules/system/audio/audio.nix
      ../../modules/system/boot/boot.nix
      ../../modules/system/containers/containers.nix
      ../../modules/system/desktop/desktop.nix
      ../../modules/system/hardware/printing.nix
      ../../modules/system/network/ssh.nix
      ../../modules/system/network/wifi.nix
      ../../modules/system/security/bitwarden-polkit.nix
      ../../modules/system/security/keepassxc-yubikey-lock.nix
      ../../modules/system/security/selinux.nix
      ../../modules/system/security/tpm2.nix
      ../../modules/system/security/yubikey.nix
      ../../modules/system/security/yubikey-notify.nix
      ../../modules/system/shell/shells.nix
      ../../modules/system/tools/homebrew.nix
      ../../modules/system/tools/packages.nix
      ../../modules/system/users/users.nix
      # Modules generated at flake-parts evaluation time: close over the
      # user list and inputs before being passed to nixosSystem.
      (import ../../modules/system/users/descriptions.nix {
        inherit inputs;
        inherit (config.dendritic) users;
      })
      # Exposes the home-manager CLI as a system package (useful for
      # `home-manager news` and `home-manager generations`).
      (
        { pkgs, inputs, ... }:
        {
          environment.systemPackages = [
            inputs.home-manager.packages.${pkgs.stdenv.hostPlatform.system}.default
          ];
        }
      )
    ];

    userModules = map mkUserModule config.dendritic.users;
  };
}
