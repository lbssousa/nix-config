# modules

Reusable Nix modules organized into two categories:

- **[system/](system/)** — System-wide modules, used by `nixos-rebuild` (NixOS modules).
- **[home/](home/)** — User-wide modules, used by `home-manager` (Home Manager modules).

## How to use

### System modules

Import them in the host's configuration file (`hosts/<host>/configuration.nix`)
or, if shared by every host, in `dendritic/features/nixos-modules.nix`'s
`sharedModules` list:

```nix
imports = [
  ../../modules/system/core/common.nix
  ../../modules/system/desktop/desktop.nix
  # ... other modules
];
```

### Home Manager modules

Import them from a user's file (`home/users/<user>/home.nix`) or from the
shared `home/common.nix`:

```nix
imports = [ ../../modules/home/apps/terminals/ghostty.nix ];
```

## Structure

```
modules/
├── system/          # NixOS modules (system-wide)
│   ├── audio/       # PipeWire / audio
│   ├── boot/        # Boot loader, Plymouth
│   ├── containers/  # Rootless Podman, Distrobox
│   ├── core/        # Base settings + impermanence
│   ├── desktop/     # Base graphical-environment config (nix-ld, portals, fonts, Bluetooth)
│   ├── hardware/    # Printing and hardware-specific config
│   ├── network/     # SSH and Wi-Fi
│   ├── security/    # TPM2, Secure Boot, YubiKey, SELinux
│   ├── shell/       # Shells (Bash, Fish, Zsh)
│   ├── tools/       # System packages
│   └── users/       # User account definitions, sudo policy
└── home/            # Home Manager modules (user-wide)
    ├── apps/
    │   ├── browsers/   # Brave, Firefox, Chrome, Edge
    │   ├── editors/    # Helix, LazyVim, nixvim, Zed
    │   ├── security/   # Bitwarden, KeePassXC, YubiKey
    │   └── terminals/  # Ghostty, tmux
    └── desktop/        # ibus-compose.nix (deprecated, see file header)
```
