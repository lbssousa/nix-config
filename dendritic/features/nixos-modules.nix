{ config, inputs, ... }:
let
  mkUserModule = username: ../../users + "/${username}.nix";
in
{
  config.dendritic.nixos = {
    sharedModules = [
      ../../modules/system/core/common.nix
      ../../modules/system/core/impermanence.nix
      ../../modules/system/audio/audio.nix
      ../../modules/system/boot/boot.nix
      ../../modules/system/containers/containers.nix
      ../../modules/system/desktop/desktop.nix
      ../../modules/system/hardware/printing.nix
      ../../modules/system/network/ssh.nix
      ../../modules/system/network/wifi.nix
      ../../modules/system/security/keepassxc-yubikey-lock.nix
      ../../modules/system/security/tpm2.nix
      ../../modules/system/security/yubikey.nix
      ../../modules/system/security/yubikey-notify.nix
      ../../modules/system/shell/shells.nix
      ../../modules/system/tools/packages.nix
      ../../modules/system/users/users.nix
      # Módulos gerados em tempo de avaliação flake-parts: fecham sobre a lista
      # de usuários e inputs antes de serem passados ao nixosSystem.
      (import ../../modules/system/users/descriptions.nix {
        inherit inputs;
        inherit (config.dendritic) users;
      })
      # Expõe o CLI do home-manager standalone como pacote de sistema.
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
