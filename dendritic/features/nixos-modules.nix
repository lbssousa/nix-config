{ config, ... }:
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
      ../../modules/system/security/tpm2.nix
      ../../modules/system/shell/shells.nix
      ../../modules/system/tools/lbnix.nix
      ../../modules/system/tools/packages.nix
      ../../modules/system/users/users.nix
    ];

    userModules = map mkUserModule config.dendritic.users;
  };
}
