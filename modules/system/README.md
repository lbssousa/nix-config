# modules/system

System-wide NixOS modules — used by `nixos-rebuild switch`.

Each subfolder groups modules by functional category.

## Categories

| Folder | Description |
|-------|-----------|
| [audio/](audio/) | PipeWire audio server with PulseAudio/JACK compatibility |
| [boot/](boot/) | Boot manager (systemd-boot/Limine) and Plymouth |
| [containers/](containers/) | Rootless Podman and Distrobox |
| [core/](core/) | Base system settings and the ephemeral-root/preservation setup |
| [desktop/](desktop/) | Desktop-agnostic base (nix-ld, XDG portals, Bluetooth, fonts) — the Noctalia v5 suite itself is wired in `dendritic/flake/noctalia-wrapper.nix`, not here |
| [hardware/](hardware/) | Printing (CUPS + Epson drivers) and hardware-specific config |
| [network/](network/) | SSH server and declarative Wi-Fi networks (NetworkManager) |
| [security/](security/) | TPM2 (automatic LUKS unlock), YubiKey (FIDO2/U2F, opt-in; fingerprint; PC/SC) |
| [shell/](shell/) | Shells available on the system (Bash, Fish, Zsh) |
| [tools/](tools/) | Essential system packages, the shared Homebrew prefix |
| [users/](users/) | User, group and sudo policy definitions |

## Usage

These modules aren't imported by hand in each host's `configuration.nix`.
`dendritic/features/nixos-modules.nix` lists all of them once, in
`dendritic.nixos.sharedModules`, and `dendritic/flake/nixos-configurations.nix`
applies that shared list — plus each host's own
`hosts/<host>/{hardware-configuration,configuration}.nix` — to every
`nixosConfigurations.<host>` output. `hosts/<host>/configuration.nix` should
stay focused on host-specific hardware or overrides, not on importing these
shared modules.
