# nix-config

Personal NixOS configuration based on Flakes, with Btrfs, declarative partitioning (disko), an ephemeral system (preservation), hybrid swap and the Noctalia v5 desktop suite.

## 🎯 Features

- ✅ **Nix Flakes**: Reproducible, declarative configuration
- ✅ **Disko**: Declarative disk partitioning
- ✅ **LUKS + LVM**: Full-disk encryption
- ✅ **Btrfs**: Modern filesystem with zstd compression, subvolumes and snapshots
- ✅ **Preservation**: Ephemeral system with tmpfs on the root — clean on every boot
- ✅ **Hybrid swap**: zram + disk swap for maximum performance
- ✅ **Noctalia v5 Desktop**: Umbriel compositor + Noctalia Shell + Noctalia Greeter, apps and fonts configured declaratively via Nix
- ✅ **Homebrew**: Available system-wide, similar to Flatpak — a few fast-moving apps (VS Code, AI CLIs) track upstream releases better there than via nixpkgs
- ✅ **Flatpak**: Browsers and apps with no nixpkgs equivalent (DistroShelf, Ignition, Warehouse, Flatseal), installed declaratively via nix-flatpak
- ✅ **Podman + Distrobox**: Rootless containers (Silverblue-like experience)
- ✅ **Home Manager**: User configuration management (as a NixOS module, and standalone)
- ✅ **Ghostty**: Modern terminal via Nix, with an undecorated profile for a quake-style drop-down
- ✅ **Multi-host**: Machine-specific configurations
- ✅ **Modular**: Shared modules for easy maintenance
- ✅ **Secure Boot**: Support via Limine (barbudus)
- ✅ **YubiKey FIDO2/U2F**: opt-in (off by default) hardware-key authentication for sudo, run0 and pkexec; password as a fallback when the YubiKey is absent
- ✅ **git-crypt**: Selective encryption of sensitive files in the repository

## 🖥️ Supported Hosts

### barbudus

- **Hardware**: Dell Inspiron 14 5490
- **CPU**: Intel i5-10210U
- **RAM**: 16 GB
- **GPU**: Intel UHD 620 + NVIDIA GeForce MX230 (PRIME offload)
- **Swap**: 20 GB on disk + 8 GB zram
- **Extras**: NVIDIA drivers + Secure Boot, Goodix fingerprint sensor

### bigodon

- **Hardware**: Morefine M6 Mini-PC
- **CPU**: Intel N200
- **RAM**: 16 GB
- **GPU**: Intel UHD Graphics (integrated)
- **Swap**: 20 GB on disk + 8 GB zram

## 📁 Project Structure

```text
.
├── flake.nix                 # Main flake entry point
├── flake.lock                # Dependency lockfile
├── dendritic/                # Top-level modules (dendritic pattern)
│   ├── imports.nix           # Automatic import of all dendritic modules
│   ├── options.nix           # Options for the `dendritic.*` namespace
│   ├── data/
│   │   ├── hosts.nix         # Host inventory (system, extra modules)
│   │   └── users.nix         # System/home user inventory
│   ├── features/
│   │   ├── local-overlay.nix # Local overlay (imports overlays/default.nix)
│   │   └── nixos-modules.nix # List of shared NixOS modules and user modules
│   └── flake/
│       ├── nixos-configurations.nix # Generates the nixosConfigurations outputs
│       └── disko-configurations.nix # Generates the diskoConfigurations outputs
├── disko.nix                 # Btrfs partitioning template (LUKS+LVM+Btrfs)
├── home/                     # Home Manager configurations (shared between the NixOS-module
│   │                         # and standalone deployment paths — see mkUserHome.nix)
│   ├── common.nix            # Base HM config — applied to all users
│   ├── mkUserHome.nix        # Shared building blocks (userModule, sharedModules)
│   └── users/                # Per-user customizations
│       └── abutre/
│           ├── home.nix      # abutre-specific config (git signing, sops age key, ...)
│           ├── noctalia.nix  # Umbriel/Noctalia keybinds, theme, dock
│           └── vscode.nix    # VS Code extensions/settings (binary comes from Homebrew)
├── hosts/                    # Host-specific configurations (NixOS)
│   ├── barbudus/
│   │   ├── configuration.nix        # Host-specific config (NVIDIA, fprintd, etc.)
│   │   ├── hardware-configuration.nix # Hardware + disko + zram
│   │   └── disko.nix                # disko parameters for this host
│   └── bigodon/
│       ├── configuration.nix
│       ├── hardware-configuration.nix
│       └── disko.nix
├── modules/                  # Shared modules (system and Home Manager)
│   ├── home/                 # Reusable Home Manager modules
│   │   ├── apps/
│   │   │   ├── nix-validation.nix
│   │   │   ├── browsers/
│   │   │   │   └── brave.nix
│   │   │   ├── homebrew.nix       # Per-user Homebrew bootstrap + declarative Brewfile
│   │   │   ├── security/
│   │   │   │   ├── bitwarden.nix  # SSH agent wiring
│   │   │   │   ├── keepassxc.nix
│   │   │   │   └── yubikey.nix
│   │   │   └── terminals/
│   │   │       ├── ghostty.nix    # Default terminal, decorated/undecorated profiles
│   │   │       └── tmux.nix
│   │   └── desktop/
│   │       └── ibus-compose.nix   # Deprecated — superseded by the tmpfiles rule
│   │                               # in modules/system/desktop/desktop.nix
│   └── system/               # System modules (nixos-rebuild)
│       ├── audio/
│       │   └── audio.nix     # PipeWire
│       ├── boot/
│       │   └── boot.nix      # systemd-boot/Limine + Plymouth (flicker-free)
│       ├── containers/
│       │   └── containers.nix # Rootless Podman + Distrobox
│       ├── core/
│       │   ├── common.nix          # Base settings (locale, nix, Btrfs)
│       │   ├── preservation.nix    # tmpfs root + persistent directories (/persist)
│       │   └── preservation-zfs.nix # ZFS variant with rollback in the initrd
│       ├── desktop/
│       │   └── desktop.nix   # nix-ld, XDG portals, Bluetooth, fonts (desktop-agnostic base)
│       ├── hardware/
│       │   └── printing.nix  # Epson ESC-P/R printer + ecbd.service
│       ├── network/
│       │   ├── ssh.nix       # SSH server
│       │   └── wifi.nix      # Declarative Wi-Fi networks (NetworkManager)
│       ├── security/
│       │   ├── tpm2.nix      # TPM2 for automatic LUKS unlock
│       │   └── yubikey.nix   # FIDO2/U2F (opt-in), fingerprint, PC/SC, keyring
│       ├── shell/
│       │   └── shells.nix    # Shells available on the system (Bash, Fish, Zsh)
│       ├── tools/
│       │   ├── homebrew.nix  # Shared Homebrew prefix + nix-ld libraries
│       │   └── packages.nix  # Essential packages (Neovim, Helix, home-manager, just, etc.)
│       └── users/
│           └── users.nix     # User accounts, groups and sudo policy
├── overlays/
│   └── default.nix           # Local overlay: custom packages added to nixpkgs
├── pkgs/                     # Custom packages (outside official nixpkgs)
│   ├── epson-printer-utility/
│   ├── fprintd-goodix/
│   ├── libfprint-goodix/     # lbssousa/libfprint fork (Goodix 538d sensor)
│   ├── tree-sitter-gregorio/
│   ├── yubikey-gpg-import/
│   └── ...                   # See overlays/default.nix for the full, current list
├── justfile                  # Just recipes for switch, HM and maintenance
├── scripts/
│   ├── install.sh            # Automated installation script
│   ├── update.sh             # Update flake inputs + nixos-rebuild switch
│   ├── enroll-tpm2.sh        # Set up LUKS unlock via TPM2
│   ├── setup-secureboot.sh   # Set up Secure Boot + sign modules (barbudus)
│   ├── import-gpg-yubikey.sh # Live-ISO: import+trust a YubiKey's GPG key (pre-install)
│   └── import-ssh-yubikey.sh # Live-ISO: download resident FIDO2 SSH keys (pre-install)
├── users/                    # NixOS user account definitions
│   ├── skeleton.nix          # Template for creating a new user
│   ├── abutre.nix            # abutre's system account
│   ├── surubi.nix            # surubi's system account
│   └── ...                   # Other users
├── .gitignore                # Ignore temporary files and keys
├── INSTALLATION.md           # Detailed installation guide
├── NIXOS_CONFIG_SPECS.md     # Project specifications
└── README.md                 # This file
```

### NixOS + Home Manager Integration

Home Manager is integrated as a NixOS module — **a single `nixos-rebuild switch` applies both
the system configuration and every managed user's**. There's no separate Home Manager
plane: everything is triggered by the same rebuild.

| Directories | What it contains |
| ---------- | ------------ |
| `dendritic/`, `hosts/`, `modules/system/`, `users/` | System (NixOS) configuration |
| `home/`, `modules/home/` | User configuration (Home Manager, applied via NixOS) |

- Any change in `home/` is applied on the next `sudo nixos-rebuild switch` (or `just switch`).
- Both use the same `nixpkgs` (pinned via `flake.lock`).

## 🚀 Quick Start

### Prerequisites

- NixOS ISO (minimal or graphical): [https://nixos.org/download.html](https://nixos.org/download.html)
- Bootable USB created from the ISO

### Installation

See the [Full Installation Guide](INSTALLATION.md) for detailed instructions.

**Automated installation with the script:**

```bash
# 1. Boot from the NixOS USB

# 2. Clone this repository
nix-shell -p git
git clone https://github.com/lbssousa/nix-config.git /tmp/nixos-config
cd /tmp/nixos-config

# 3. Run the installation script as root (interactive step-by-step guide)
sudo bash scripts/install.sh

# To see all available options:
sudo bash scripts/install.sh --help
```

**Non-interactive installation (full example):**

```bash
sudo bash scripts/install.sh \
  --host barbudus \
  --disk /dev/nvme0n1 \
  --user "cavalo:sudo" \
  --non-interactive
```

**Manual installation (step by step):**

```bash
# 1. Boot from the NixOS USB

# 2. Enable flakes
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf

# 3. Clone this repository
nix-shell -p git
git clone https://github.com/lbssousa/nix-config.git /tmp/nixos-config
cd /tmp/nixos-config

# 4. Adjust the device in the host's disko.nix
# For barbudus:
nano hosts/barbudus/disko.nix  # Adjust /dev/nvme0n1 if needed
# For bigodon:
nano hosts/bigodon/disko.nix

# 5. Partition and install (⚠️ ERASES ALL DATA ON THE DISK!)
# Creates: tmpfs root + Btrfs subvolumes (@home, @nix, @persist, @log, ...)
HOST=barbudus  # or bigodon
sudo nix run github:nix-community/disko -- --mode disko ./hosts/$HOST/disko.nix

# 6. Install NixOS
sudo nixos-install --flake .#$HOST

# 7. Set the user's password
sudo nixos-enter --root /mnt
passwd your-username
exit

# 8. Reboot
sudo reboot
```

### Updating the system

```bash
# Update flake inputs and rebuild the system (recommended):
sudo bash scripts/update.sh

# Only update flake inputs (no rebuild):
sudo bash scripts/update.sh --update-only

# Only rebuild (without updating inputs):
sudo bash scripts/update.sh --rebuild-only
```

### System switch (includes Home Manager)

```bash
# Via Just — automatically elevates with run0 (polkit/YubiKey):
just switch                  # current host
just switch barbudus         # specific host

# Or via shell alias (available after the first switch):
nrs   # nixos-rebuild switch (NixOS + HM)
nrb   # nixos-rebuild boot   (applies on the next boot)
nru   # updates inputs + switch
```

> Every user's Home Manager configuration is applied automatically on every
> system rebuild — no additional command is needed.

### Shell aliases (bash/zsh)

Defined in `home/common.nix` and available in interactive sessions after the first `just switch`.
All NixOS aliases use `run0` for privilege elevation via polkit/YubiKey
(no password prompt), and pass `SSH_AUTH_SOCK` through so `nixos-rebuild` can access
SSH-gated flake inputs (e.g. `nix-secrets`).
Since Home Manager is a NixOS module, every rebuild applies NixOS and HM together.

| Alias | Effect |
|-------|--------|
| `nrs` | `nixos-rebuild switch` — applies NixOS + HM and activates immediately |
| `nrb` | `nixos-rebuild boot` — prepares the next boot, current session unchanged |
| `nru` | `nix flake update` + `nixos-rebuild switch` — updates inputs and applies |
| `hmn` | `home-manager news` — shows the HM changelog since the last generation |

The `_nix_cfg()` helper function resolves the flake path automatically:
`/etc/nixos` on deployed systems, or `$PROJECTS/lbssousa/nix-config`
in development checkouts. The `just()` wrapper always points to
`$(_nix_cfg)/justfile`, so `just switch` works from any directory.

### Rollback

```bash
# List available generations
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# Go back to the previous generation
sudo nixos-rebuild switch --rollback
```

## 🔧 Adding a User

### 1. Create the system account

1. Copy the user template:

   ```bash
   cp users/skeleton.nix users/your-username.nix
   ```

2. Edit `users/your-username.nix` and replace `skeleton` with the username.

3. Add the file to the git index:

   ```bash
   git add users/your-username.nix
   ```

4. Add the user to the system inventory:

   > With the dendritic architecture, this is centralized in the inventory.
   > Add the login to `dendritic/data/users.nix`.

   Example:

   ```nix
   config.dendritic.users = [
     "abutre"
     "surubi"
     "coruja"
     "camelo"
     "cavalo"
     "macaco"
     "your-username"
   ];
   ```

5. Rebuild the system:

   ```bash
   just switch
   ```

### 2. Configure the user's Home Manager (optional)

For a custom HM configuration (beyond the default `home/common.nix`):

1. Create the user's customization file:

   ```bash
   mkdir -p home/users/your-username
   cp home/users/abutre/home.nix home/users/your-username/home.nix
   # Edit as needed
   ```

2. `dendritic/flake/home-nixos-module.nix` automatically detects the
   `home/users/<username>/home.nix` file and imports it for the corresponding user.

3. Apply with a normal system rebuild:

   ```bash
   just switch
   ```

> Users with no customization automatically keep receiving only `home/common.nix`.

## 🖥️ Adding a New Host

1. Create the `hosts/<new-host>/` directory with the files:
   - `configuration.nix` — host-specific settings (no shared imports list)
   - `hardware-configuration.nix` — generated by `nixos-generate-config`
   - `disko.nix` — partitioning parameters (copy from an existing host)

2. Add the host to the dendritic inventory in `dendritic/data/hosts.nix`:

   ```nix
   config.dendritic.hosts = {
     # ...existing hosts...
     new-host = {
       system = "x86_64-linux";
       extraNixosModules = [ ];
     };
   };
   ```

3. Add the host's files to the git index (`git add`) before evaluating the flake,
   since flakes ignore untracked files.

## 📡 Configuring Wi-Fi Networks

Edit `modules/system/network/wifi.nix` to declare Wi-Fi networks via NetworkManager.
The password's PBKDF2 hash (safer than plaintext) can be generated with:

```bash
nix-shell -p wpa_supplicant --run "wpa_passphrase NetworkName PasswordHere"
```

Use the value of the `psk=` field (without the `#`) as the `psk` value in the connection profile.

## 🔑 File Encryption (git-crypt)

This repository supports **git-crypt** to encrypt sensitive files tracked by git.
Files marked with the `git-crypt` filter appear as readable text for collaborators with the
key, and as encrypted binary data for everyone else. `git-crypt` is available on every
system managed by this repository.

### Unlocking the repository after cloning

If the repository has encrypted files, unlock them before any build:

```bash
# With a symmetric key (exported file):
git-crypt unlock /path/to/git-crypt.key

# With a GPG key (configured in the keyring):
git-crypt unlock
```

> ⚠️ **Important for Nix flakes**: unlocked encrypted files appear as binary data
> in the repository. The Nix evaluator will try to parse them as code and fail with a
> syntax error. Always run `git-crypt unlock` before `just switch` or
> `nixos-rebuild`.

### Adding encrypted files to the repository

```bash
# 1. Initialize git-crypt (only once per repository):
git-crypt init

# 2. Export the symmetric key for a secure backup (keep it outside the repository):
git-crypt export-key ~/git-crypt-nixos-config.key

# 3. Mark files for encryption via .gitattributes:
echo "path/to/file filter=git-crypt diff=git-crypt" >> .gitattributes
git add .gitattributes path/to/file
git commit -m "Add encrypted secret file"
# The file is automatically encrypted on push and on clone for anyone without the key.
```

## 🍺 Homebrew

Available system-wide, similar to Flatpak: a shared prefix at
`/home/linuxbrew/.linuxbrew`, group-writable by every normal user. Set up in
two parts:

- `modules/system/tools/homebrew.nix` — creates the shared prefix (owned by
  the `linuxbrew` group) and extends `nix-ld` with the libraries
  Electron/GTK casks need.
- `modules/home/apps/homebrew.nix` — per-user bootstrap (installs Homebrew
  itself on first run) and a declarative Brewfile, applied via a
  `systemd --user` service (Homebrew's installer refuses to run as root, so
  this can't be a system-level service the way Flatpak's is).

Includes the [`ublue-os/homebrew-tap`](https://github.com/ublue-os/homebrew-tap)
tap and the [`bbrew`](https://github.com/Valkyrie00/bold-brew) TUI. A few apps
that update very frequently upstream (VS Code, `claude-code`, `copilot-cli`,
`opencode`) are installed via Homebrew instead of nixpkgs — see the Brewfile
in `modules/home/apps/homebrew.nix` for the current list.

## 📱 Flatpaks

Most desktop applications are installed directly via Nix
(`environment.systemPackages`) or Homebrew (see above). Flatpak covers
browsers and a handful of apps with no adequate nixpkgs equivalent — see
`dendritic/flake/noctalia-wrapper.nix` for the authoritative, current list:

| Flatpak App | Description |
|-------------|-----------|
| `com.bitwarden.desktop` | Password manager |
| `com.github.tchx84.Flatseal` | Flatpak permissions manager |
| `com.ranfdev.DistroShelf` | Container distro manager |
| `io.github.flattool.Ignition` | Flatpak autostart manager |
| `io.github.flattool.Warehouse` | Flatpak app manager |
| `org.mozilla.firefox` | Default browser |
| `com.brave.Browser` | Alternate browser / PWAs |
| `us.zoom.Zoom` | Video conferencing |

These Flatpaks are **installed automatically** on the first boot with
internet available (via nix-flatpak's `flatpak-managed-install` service).
No manual action is needed. Daily automatic updates are also
configured.

To install additional applications manually:

```bash
# Users in the 'wheel' group can install system-wide Flatpaks without a password
flatpak install flathub <app-id>

# Example:
flatpak install flathub org.gimp.GIMP
```

## 🔒 Post-Installation Configuration

### YubiKey FIDO2/U2F (optional, off by default)

FIDO2/U2F-based PAM/PolKit authentication is **opt-in**: set
`security.fido2Auth.enable = true;` (see `modules/system/security/yubikey.nix`)
on a host to require a YubiKey touch for `sudo`, `run0`, the graphical greeter
and `pkexec`. Fingerprint auth, PC/SC and the keyring stay on regardless of
this flag.

> 💡 Once enabled: when `/persist/etc/u2f-mappings` exists and contains the
> user's entry, those tools require a YubiKey touch. If the file doesn't
> exist or the user has no entry in it, PAM automatically falls back to
> **password** authentication — no lockout.

Registering a key (`pamu2fcfg`) should be done **during installation**, before
the first reboot — see [step 10 of the installation guide](INSTALLATION.md)
for complete instructions. If it was skipped, the system still works normally
via password; see
[Register YubiKey after the first boot](INSTALLATION.md#-troubleshooting) in
the installation guide.

### Secure Boot (barbudus only)

After the first boot, with Secure Boot **disabled** in the UEFI (Setup Mode):

```bash
sudo bash scripts/setup-secureboot.sh
```

Then enable Secure Boot in the UEFI and reboot.

### Automatic LUKS Unlock via TPM2

After a successful first boot:

```bash
sudo bash scripts/enroll-tpm2.sh
```

## 📚 Documentation

- **[INSTALLATION.md](INSTALLATION.md)**: Full installation guide
- **[NIXOS_CONFIG_SPECS.md](NIXOS_CONFIG_SPECS.md)**: Project specifications and requirements
- **[modules/home/apps/terminals/README.md](modules/home/apps/terminals/README.md)**: tmux keybindings

## 🔗 References

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Disko](https://github.com/nix-community/disko)
- [Preservation](https://github.com/nix-community/preservation)
- [Home Manager](https://github.com/nix-community/home-manager)
- [NixOS Hardware](https://github.com/NixOS/nixos-hardware)
- [Limine Bootloader](https://github.com/limine-bootloader/limine)
- [nix-flatpak](https://github.com/gmodena/nix-flatpak)
- [Noctalia](https://docs.noctalia.dev/) / [Umbriel](https://github.com/noctalia-dev/umbriel) / [Noctalia Greeter](https://github.com/noctalia-dev/noctalia-greeter)
- [Homebrew on Linux](https://docs.brew.sh/Homebrew-on-Linux) / [ublue-os/homebrew-tap](https://github.com/ublue-os/homebrew-tap)
- [Ghostty](https://ghostty.org/)
- [Erase Your Darlings (ephemeral system)](https://grahamc.com/blog/erase-your-darlings/)
- [Btrfs on NixOS](https://nixos.wiki/wiki/Btrfs)
- [Arch Wiki — Btrfs](https://wiki.archlinux.org/title/Btrfs)
- [EmergentMind/nix-config](https://github.com/EmergentMind/nix-config) — NixOS repository organization reference
