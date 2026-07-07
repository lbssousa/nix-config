# modules

Reusable Nix modules organized into two categories:

- **[system/](system/)** — System-wide modules, used by `nixos-rebuild` (NixOS modules).
- **[user/](user/)** — User-wide modules, used by `home-manager` (Home Manager modules).

## How to use

### System modules

Import them in the host's configuration file (`hosts/<host>/configuration.nix`):

```nix
imports = [
  ../../modules/system/core/common.nix
  ../../modules/system/desktop/desktop.nix
  # ... other modules
];
```

### User modules

Import them in the user's file (`users/<user>.nix`) or directly in the home-manager configuration:

```nix
home-manager.users.myuser = { imports = [ ../../modules/user/apps/brave.nix ]; ... };
```

## Structure

```
modules/
├── system/          # NixOS modules (system-wide)
│   ├── audio/       # PipeWire / audio
│   ├── boot/        # Boot loader, Plymouth
│   ├── containers/  # Rootless Podman, Distrobox
│   ├── core/        # Base settings + impermanence + users
│   ├── desktop/     # GNOME + Flatpak
│   ├── hardware/    # Printing and hardware-specific config
│   ├── network/     # SSH and networking
│   ├── security/    # TPM2, Secure Boot
│   ├── shell/       # Shells (Bash, Fish, Zsh)
│   ├── tools/       # System packages
│   └── users/       # User definitions, sudo
└── user/            # Home Manager modules (user-wide)
    ├── apps/        # User applications (Brave, etc.)
    ├── dev/         # Development tools
    └── shell/       # User shell configuration
```
