# modules/system

System-wide NixOS modules — used by `nixos-rebuild switch`.

Each subfolder groups modules by functional category.

## Categories

| Folder | Description |
|-------|-----------|
| [audio/](audio/) | PipeWire audio server with PulseAudio/JACK compatibility |
| [boot/](boot/) | Boot manager (systemd-boot/Limine) and Plymouth |
| [containers/](containers/) | Rootless Podman and Distrobox |
| [core/](core/) | Base system settings and impermanence |
| [desktop/](desktop/) | GNOME + Flatpak environment (Silverblue/Bluefin-like experience) |
| [hardware/](hardware/) | Printing (CUPS + Epson drivers) and hardware-specific config |
| [network/](network/) | SSH server and declarative Wi-Fi networks (NetworkManager) |
| [security/](security/) | TPM2 for automatic LUKS unlock |
| [shell/](shell/) | Shells available on the system (Bash, Fish, Zsh) |
| [tools/](tools/) | Essential system packages |
| [users/](users/) | User, group and sudo policy definitions |

## Usage

Import the desired modules in the host's configuration file:

```nix
# hosts/<host>/configuration.nix
imports = [
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
  ../../modules/system/tools/packages.nix
  ../../modules/system/users/users.nix
];
```
