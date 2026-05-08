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
      ../../modules/system/shell/shells.nix
      ../../modules/system/tools/packages.nix
      ../../modules/system/users/users.nix
      # Módulo gerado em tempo de avaliação flake-parts: fecha sobre a lista de
      # usuários e inputs antes de ser passado ao nixosSystem.
      (import ../../modules/system/users/descriptions.nix {
        inherit inputs;
        users = config.dendritic.users;
      })
    ];

    userModules = map mkUserModule config.dendritic.users;
  };
}
