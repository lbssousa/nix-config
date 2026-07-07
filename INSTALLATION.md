# NixOS Installation Guide

This guide covers installing NixOS using this Flakes-based configuration with Btrfs, disko, preservation and hybrid swap.

## 📋 Prerequisites

1. Download the NixOS ISO: [https://nixos.org/download.html](https://nixos.org/download.html)
2. Create a bootable USB with the ISO
3. Boot from the NixOS USB
4. **YubiKey with a GPG key** (recommended): needed to unlock the `nix-keys`
   repository via git-crypt. Without it, sops-nix secrets (e.g. Wi-Fi password)
   won't be configured during installation and will need to be restored manually.

## 🚀 Installation

### Automated Installation Script (`install.sh`)

The repository includes the `scripts/install.sh` script, which automates every installation step described in this guide. It's the fastest and safest way to install the system.

#### How to use it

```bash
# 1. Boot from the NixOS USB

# 2. Clone the configuration repository
nix-shell -p git
git clone https://github.com/lbssousa/nix-config.git /tmp/nixos-config
cd /tmp/nixos-config

# 3. (Optional, but recommended) Clone and unlock nix-keys
#    nix-keys stores sops-nix's age keys (encrypted with git-crypt).
#    Without it, system secrets (e.g. Wi-Fi via sops-nix) won't work after boot.
nix-shell -p git git-crypt gnupg
git clone git@github.com:lbssousa/nix-keys.git /tmp/nix-keys
cd /tmp/nix-keys && git-crypt unlock  # requires the YubiKey to be inserted
cd /tmp/nixos-config

# 4. Run the script as root (interactive mode — recommended for most cases)
sudo bash scripts/install.sh
#    The script will automatically detect nix-keys at /tmp/nix-keys and copy
#    the system age key to /persist/etc/sops/age/keys.txt.
```

The script will guide you through each step, asking for the required information.

#### Script options

```text
Usage:
  bash scripts/install.sh [--host <hostname>] [--disk <device>]
                          [--partition-profile <btrfs|zfs>]
                          [--user "login:Full Name:sudo"]
                          [--user "login2:Name2:nosudo"] ...
                          [--nix-keys-dir <path>]
                          [--age-keys-backup <file>]
                          [--non-interactive]
                          [--help]

Options:
  --host              NixOS host name (e.g. barbudus, bigodon).
                      If omitted, it's asked interactively.
  --disk              Target disk device (e.g. /dev/nvme0n1, /dev/sda).
                      If omitted, it's asked interactively.
  --partition-profile Partitioning profile: btrfs (default) or zfs.
                      If omitted, it's asked interactively.
  --user              User in the format "login:Full Name:sudo|nosudo".
                      Can be repeated to create multiple users.
                      "sudo" (default) adds the user to the wheel (sudo) group.
                      "nosudo" creates the user without sudo permission.
                      If omitted, it's asked interactively.
  --nix-keys-dir      Path to the local clone of the nix-keys repository
                      (private repository with sops-nix age keys, encrypted with
                      git-crypt). If omitted, looks in ../nix-keys (sibling of nix-config).
  --age-keys-backup   Direct path to the system age key's keys.txt file.
                      Alternative to --nix-keys-dir when you only have the file.
  --non-interactive   Doesn't ask questions; fails if required information
                      isn't provided via flags.
  --help, -h          Show this help and exit.
```

To see the help directly:

```bash
sudo bash scripts/install.sh --help
```

#### Examples

**Fully interactive installation** (recommended for beginners):

```bash
sudo bash scripts/install.sh
```

**Non-interactive installation** (useful for automation or reinstalls):

```bash
sudo bash scripts/install.sh \
  --host barbudus \
  --disk /dev/nvme0n1 \
  --partition-profile btrfs \
  --nix-keys-dir /tmp/nix-keys \
  --user "cavalo:sudo" \
  --user "macaco:nosudo" \
  --non-interactive
```

**Pre-select the host and disk, but confirm users interactively:**

```bash
sudo bash scripts/install.sh --host bigodon --disk /dev/sda
```

#### What the script does

1. Enables Flakes and the nix-community cache for root in the live environment
2. Clones and unlocks the `nix-keys` repository via git-crypt (requires a YubiKey or symmetric key)
3. Lists available hosts and disks for selection
4. Selects the partitioning profile (Btrfs or ZFS)
5. Updates the host's `disko.nix` with the chosen disk
6. Partitions and formats the disk with disko (⚠️ erases all data!)
   - The root (`/`) is configured as tmpfs — automatically wiped on every boot
   - Persistent data lives in dedicated Btrfs subvolumes (or ZFS datasets)
7. Creates user files from the skeleton
8. Adds the user files to the git index (`git add`)
9. Updates `configuration.nix` with the user imports
10. Creates Secure Boot keys in `/persist/etc/secureboot` (only for hosts with Secure Boot via Limine)
11. Copies the system age key from `nix-keys` to `/persist/etc/sops/age/keys.txt`
    — lets sops-nix decrypt secrets (Wi-Fi, etc.) on the first boot
12. Copies the configuration to `/mnt/etc/nixos` and runs `nixos-install`
13. Automatically copies Wi-Fi connections from the live CD to `/persist/etc/NetworkManager/system-connections`
    — Wi-Fi will already be configured on the first boot, no need to retype credentials
14. Sets passwords via `passwd --root` and copies `/etc/shadow` to `/persist`

### Manual Installation (step by step)

```bash
# Connect to the internet (if needed)
# For Wi-Fi via NetworkManager:
nmcli device wifi list
nmcli device wifi connect "SSID" password "password"

# Set the keyboard layout
loadkeys br-abnt2

# Enable SSH for remote installation (optional)
sudo systemctl start sshd
passwd  # Set a temporary password for the live environment

# Temporarily enable Flakes and the nix-community cache.
# The cache avoids compiling dependencies from scratch and download failures.
mkdir -p ~/.config/nix
cat >> ~/.config/nix/nix.conf <<EOF
experimental-features = nix-command flakes
extra-substituters = https://nix-community.cachix.org
extra-trusted-public-keys = nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCUSeBs=
EOF
```

### 2. Clone the repositories

```bash
# Install git in the live environment
nix-shell -p git git-crypt gnupg

# Clone the system configuration (public repository)
git clone https://github.com/lbssousa/nix-config.git /tmp/nixos-config
cd /tmp/nixos-config
```

#### 2b. Clone and unlock nix-keys (the keys repository)

The `nix-keys` repository is a **private** (SSH) repository that stores `sops-nix`'s
age keys, encrypted with `git-crypt`. It's required for the system secrets to be
configured correctly after installation.

`nix-keys` structure:
- `sops/age/keys.txt` — **system age key** (decrypts NixOS secrets, like the
  Wi-Fi password). Copied to `/persist/etc/sops/age/keys.txt` during installation.
- `sops/age/<user>/keys.txt` — each user's **personal age key** (decrypts
  Home Manager secrets, like rclone credentials). Copied automatically by
  the Home Manager activation script on **first login** — not needed during
  installation.

```bash
# Clone nix-keys as a sibling of nix-config (auto-detected by install.sh)
git clone git@github.com:lbssousa/nix-keys.git /tmp/nix-keys

# Unlock with git-crypt (requires the YubiKey inserted or an exported symmetric key)
cd /tmp/nix-keys
gpg --card-status              # verify the YubiKey is recognized by GPG
git-crypt unlock               # unlock via GPG (YubiKey)
# or: git-crypt unlock /path/to/git-crypt.key  # via symmetric key

cd /tmp/nixos-config
```

> If `nix-keys` isn't available during installation, the system will install
> normally but sops-nix secrets (e.g. Wi-Fi connections managed by sops) won't
> be active until the key is restored manually to
> `/persist/etc/sops/age/keys.txt`.

### 3. Identify the installation disk

```bash
# List available disks
lsblk

# Or with more detail:
fdisk -l

# Identify the correct disk (e.g. /dev/nvme0n1 for NVMe, /dev/sda for SATA)
```

### 4. Adjust the disk configuration

Edit the desired host's disko file to set the correct device:

```bash
# For barbudus (Dell Inspiron 14 5490):
nano hosts/barbudus/disko.nix

# For bigodon (Morefine M6):
nano hosts/bigodon/disko.nix
```

Change `device = "/dev/nvme0n1"` to the correct disk identified in the previous step.

### 5. Partition and format the disk

⚠️ **WARNING**: This command WILL ERASE ALL DATA ON THE SELECTED DISK!

```bash
# Choose the appropriate host
HOST=barbudus  # or bigodon

# Run disko to partition and format
sudo nix run github:nix-community/disko \
  --option extra-substituters "https://nix-community.cachix.org" \
  --option extra-trusted-public-keys "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCUSeBs=" \
  -- --mode disko ./hosts/$HOST/disko.nix
```

This command will:

1. Create GPT partitions (512MB EFI + LUKS partition)
2. Set up LUKS encryption (you'll be asked for a password during the process)
3. Create LVM volumes (20GB swap + Btrfs volume)
4. Configure the root (`/`) as **tmpfs** — automatically wiped on every boot
5. Format the Btrfs volume and create the persistent data subvolumes:
   - `@home` → `/home`
   - `@nix` → `/nix`
   - `@persist` → `/persist`
   - `@log` → `/var/log`
   - `@containers` → `/var/lib/containers`
   - `@flatpak` → `/var/lib/flatpak`
   - `@snapshots` → `/.snapshots`
6. Mount everything at `/mnt`

### 6. Generate the hardware configuration (recommended)

```bash
# Generate an automatic hardware-configuration.nix
nixos-generate-config --no-filesystems --root /mnt

# Merge it with the host's file (or replace it entirely)
# IMPORTANT: Keep the "import ./disko.nix" line in the imports
# and the zramSwap settings from the original file
sudo cp /mnt/etc/nixos/hardware-configuration.nix ./hosts/$HOST/hardware-configuration.nix
```

After copying, edit the file to:

1. Keep `import ./disko.nix` in the imports
2. Add the `zramSwap` settings
3. Keep `fileSystems."/persist".neededForBoot = true`

### 7. Create user files

You can create **one or more user accounts**. For each account, set the login name, full name and whether it will have **sudo** permission (`wheel` group) or not.

```bash
# Copy the template for the desired user(s)
cp users/skeleton.nix users/your-username.nix

# Edit the file (replace "skeleton" with the actual username)
nano users/your-username.nix
```

To **create a second user without sudo**, copy the skeleton again and remove the `"wheel"` line from `extraGroups`:

```bash
cp users/skeleton.nix users/other-user.nix
nano users/other-user.nix
# Remove the line: "wheel" # sudo
```

With the dendritic architecture, wiring system users is centralized.
Edit `dendritic/data/users.nix` and add the logins to the `config.dendritic.users` list.

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
  "other-user"
];
```

> ⚠️ **IMPORTANT — add the file to the git index**
>
> Nix evaluates flakes from the **git index**, not the filesystem
> directly. Untracked files not in the index are
> **invisible to Nix** and never reach `/nix/store`, causing
> _"module not found"_ errors in `nixos-install`.
>
> Run the command below to add the file to the index:
>
> ```bash
> git add users/your-username.nix
> ```

### 8. Install NixOS

> **Only for `barbudus` (Secure Boot via Limine):** create the Secure Boot keys _before_ `nixos-install`. Without this, the installer fails with `Failed to install bootloader`.
>
> ```bash
> sudo mkdir -p /mnt/persist/etc/secureboot
> sudo nix run \
>   --option extra-substituters "https://nix-community.cachix.org" \
>   --option extra-trusted-public-keys "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCUSeBs=" \
>   nixpkgs#sbctl -- --disable-landlock create-keys \
>   --export /mnt/persist/etc/secureboot/keys \
>   --database-path /mnt/persist/etc/secureboot/GUID
> ```
>
> > **Why `--disable-landlock`?** sbctl activates the Landlock sandbox (a Linux LSM) before
> > processing the path flags. Landlock is configured with the default path
> > `/var/lib/sbctl`, blocking any access to `/mnt/persist/etc/secureboot` — even
> > for root. This causes the error `sbctl requires root to run: open ... permission denied`.
> >
> > **Why two path flags?** `--database-path` sets only the GUID file; `--export`
> > sets the keys directory. Together they create the full structure that
> > sbctl expects at `/var/lib/sbctl` (a symlink to `/persist/etc/secureboot`, created
> > via `systemd.tmpfiles.rules` on the host — the `boot.loader.limine` module has no
> > `pkiBundle`-style option, the path is always fixed):
> > `GUID`, `keys/PK/`, `keys/KEK/`, `keys/db/`.

```bash
# Copy the configuration to /mnt
sudo cp -r /tmp/nixos-config /mnt/etc/nixos

# Install the system
# The --option flags pass the nix-community cache explicitly, making the
# installation resilient to dependency download failures.
# --option accept-flake-config true applies the flake's nixConfig (substituter + key)
# at the same time, avoiding warnings about untrusted substituters.
DESKTOP=plasma  # or gnome
sudo nixos-install \
  --flake /mnt/etc/nixos#${HOST}-${DESKTOP} \
  --option accept-flake-config true \
  --option extra-substituters "https://nix-community.cachix.org" \
  --option extra-trusted-public-keys "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCUSeBs="
```

During installation you'll be asked for:

- A password for the root user (after installation)

### 9. Configure passwords

Users created with `initialPassword = "nixos"` (the skeleton's default) **will be prompted to create their own password on first login**. There's no need to set passwords manually.

If you prefer to set custom passwords during installation, copy the shadow file to `/persist` so it survives the next boot (the tmpfs root is reset on every boot; `/persist` is preserved via Btrfs):

```bash
# Enter the newly installed system
sudo nixos-enter --root /mnt

# Set a password for each user created
passwd your-username
passwd other-user  # if there's more than one

# Set a password for root (optional, but recommended)
passwd root

exit

# IMPORTANT: copy shadow to /persist (persists across boots via preservation)
sudo mkdir -p /mnt/persist/etc
sudo cp -p /mnt/etc/shadow /mnt/persist/etc/shadow

# Create flag files to avoid a forced change on first login
# (only for users who already set their password above)
sudo touch /mnt/persist/.password-change-required-<your-username>
```

> **Note:** If passwords are set via `nixos-enter` without copying the shadow file to `/persist`, they'll be lost after the first reboot — the tmpfs root is always reset to an empty state (preservation only saves what's explicitly declared). Users will get the temporary `nixos` password and be prompted to change it.

### 10. Register the YubiKey for U2F authentication

> 💡 **Recommended for users in the `wheel` group**: when `/persist/etc/u2f-mappings` exists
> and contains the user's entry, `sudo`, `run0` and `pkexec` require a YubiKey touch.
> If the file doesn't exist or the user has no entry in it, PAM automatically falls back
> to **password** authentication — no lockout.

With the YubiKey inserted, run this **in the live environment** (outside `nixos-enter`):

```bash
# Register the first wheel user (creates the file):
pamu2fcfg -u your-username > /mnt/persist/etc/u2f-mappings
# Touch the YubiKey when its LED blinks

# Add each additional wheel user (appends to the file):
pamu2fcfg -u other-user >> /mnt/persist/etc/u2f-mappings

# To register a second backup YubiKey for the same user,
# use -n (without the user prefix) and concatenate it manually into the file,
# or repeat the process with the backup key instead of the primary one.
```

Check the result — there should be a line starting with each `wheel` user's name:

```bash
cat /mnt/persist/etc/u2f-mappings
```

### 11. Finish the installation

```bash
# Unmount and reboot
sudo umount -R /mnt
sudo reboot
```

## 🔐 First Boot

1. **LUKS unlock**: Enter the encryption password set during disko
2. **Login**: Use the created user with the password set during installation.
   If no password was set, use the temporary password **`nixos`** — the system will ask you to change it immediately.
3. **YubiKey U2F** — recommended check before trying `sudo` or `run0`:

   ```bash
   cat /persist/etc/u2f-mappings
   ```

   The file should have a line starting with each `wheel` group user's name.
   If the file doesn't exist (step 10 was skipped), `sudo`, `run0` and `pkexec` still
   work via password — PAM automatically falls back to password authentication when
   there's no valid U2F mapping.

4. **sops-nix secrets** (Wi-Fi and others): if the system age key was copied
   during installation (step 6b), the secrets will activate automatically. Check:

   ```bash
   ls /persist/etc/sops/age/keys.txt  # should exist
   systemctl status sops-nix          # should show "active"
   ```

   If the file doesn't exist, clone and unlock nix-keys first, then copy the key:
   ```bash
   # Clone and unlock nix-keys (only needed if not done during installation)
   NIX_KEYS="$(xdg-user-dir PROJECTS)/lbssousa/nix-keys"
   git clone git@github.com:lbssousa/nix-keys.git "$NIX_KEYS"
   cd "$NIX_KEYS" && git-crypt unlock  # requires the YubiKey inserted

   # Copy the system age key to /persist
   run0 install -Dm600 "$NIX_KEYS/sops/age/keys.txt" /persist/etc/sops/age/keys.txt

   # Regenerate the secrets now that the key is available
   cd /etc/nixos && just nixos switch
   ```

5. **Flatpaks** (automatic installation):

   The Flatpaks declared in the configuration are installed automatically by the
   `flatpak-managed-install` service the first time the system boots with internet access.
   No manual action is needed.


## 🥾 Boot Menu (systemd-boot)

The systemd-boot menu is **hidden by default** (`timeout = 0`) for a faster,
flicker-free boot.

### How to show the boot menu

- **During boot**: hold down the **Space** key (or any key) right after the
  UEFI firmware screen appears. The systemd-boot menu will be displayed.

- **Temporarily via terminal** (sets a timeout until the next rebuild): `sudo bootctl set-timeout 5`

- **To revert to the quiet behavior**: `sudo bootctl set-timeout 0`

## 🔒 Secure Boot Configuration (barbudus only)

The PKI keys are created automatically during installation (step 9 of the script, or manually before `nixos-install`). What's left after the first boot is to **enroll the keys in the UEFI firmware**.

### ⚠️ Limine vs. MOK/shim — an important difference

This configuration uses **Limine** (`boot.loader.limine.secureBoot`), which does **NOT** use shim or MOK.

- **There will be no** blue MOKmanager screen during boot
- **You won't be asked** for a MOK password
- The firmware only verifies the PE signature of the Limine binary, made with its own
  PKI keys (PK/KEK/db) enrolled in the UEFI firmware
- Kernel/initrd integrity is guaranteed by a BLAKE2B checksum embedded in
  `limine.conf` (whose hash, in turn, is embedded in the signed Limine binary
  via `enroll-config`) — not by an individual signature on each file
- The keys live in `/persist/etc/secureboot`, symlinked to `/var/lib/sbctl`
  (the fixed path sbctl expects; the `boot.loader.limine` module has no
  option equivalent to lanzaboote's `pkiBundle`)

The absence of a MOK screen is **expected and correct** in this configuration.

### ⚠️ Prerequisite: Setup Mode active

To enroll the PKI keys, the firmware needs to be in **Setup Mode** (no Secure
Boot keys registered). If Setup Mode isn't active, enrollment will fail.

**How to check/enable Setup Mode:**

1. Reboot and enter the BIOS/UEFI (F2, F12, Del or Esc during boot)
2. In the Secure Boot section, look for **"Delete All Secure Boot Keys"**, **"Setup Mode"**,
   **"Clear Secure Boot Keys"** or a similar option
3. Clear the existing keys (this enables Setup Mode)
4. Save and reboot into NixOS with Secure Boot **disabled**

The `setup-secureboot.sh` script automatically checks Setup Mode and aborts with
clear instructions if the firmware isn't in Setup Mode.

### Step by step to set up Secure Boot

```bash
# 1. Boot into the system normally (Secure Boot disabled in the BIOS, Setup Mode active)

# 2. Check the current state of the keys and Setup Mode
sudo sbctl status

# 3. Run the setup script (checks Setup Mode, enrolls keys and signs binaries)
sudo bash /etc/nixos/scripts/setup-secureboot.sh

# 4. Rebuild to make sure the latest binaries are signed
sudo nixos-rebuild switch --flake /etc/nixos#barbudus

# 5. Enable Secure Boot in the BIOS/UEFI and reboot

# 6. Verify everything is correct after the reboot
sudo sbctl status
sudo bash /etc/nixos/scripts/setup-secureboot.sh --verify-only
```

> **Note:** If the keys don't exist in `/persist/etc/secureboot` (a manual installation without the sbctl step), create them with `sudo sbctl create-keys` before proceeding.

## 🔑 Automatic LUKS Unlock via TPM2

This configuration includes support for automatically unlocking the LUKS volume using the hardware's TPM2 chip. When configured, the system unlocks the disk automatically during boot, without asking for a password — as long as the system's integrity measurements haven't changed.

### How It Works

The TPM2 stores the LUKS key protected by **PCRs (Platform Configuration Registers)** — measurements of the firmware and boot loader state. If the hardware or software is tampered with, the PCRs change and the TPM2 refuses to release the key, requiring the recovery password.

**Configured PCRs:**

| PCR | What it measures                      |
| --- | ------------------------------------- |
| 0   | UEFI firmware (BIOS integrity)        |
| 2   | UEFI option code (ROM drivers)        |
| 7   | Secure Boot state                     |

### Enroll the TPM2 for the LUKS Volume

Run this after the first boot with the installed system:

```bash
# Check whether the TPM2 is available
ls /dev/tpm* && tpm2_getcap properties-fixed 2>/dev/null | head -5

# Identify the LUKS partition
# (usually the second partition of the installation disk)
lsblk -f | grep crypto_LUKS

# Enroll the TPM2 (replace /dev/nvme0n1p2 with your LUKS partition)
sudo systemd-cryptenroll \
  --tpm2-device=auto \
  --tpm2-pcrs=0+2+7 \
  /dev/disk/by-partlabel/luks

# Or using the device directly:
# sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+2+7 /dev/nvme0n1p2
```

During enrollment, you'll be asked for the current LUKS password to authorize adding the TPM2.

### Test the Unlock

```bash
# Check the configured LUKS slots
sudo cryptsetup luksDump /dev/disk/by-partlabel/luks | grep -A5 "Tokens\|Keyslots"

# Reboot to test the automatic unlock
sudo reboot
```

### Removing the TPM2 (Revocation)

To revoke TPM2 access (e.g. before selling or repairing the hardware):

```bash
# Remove the TPM2 token and its associated keyslot
sudo systemd-cryptenroll --wipe-slot=tpm2 /dev/disk/by-partlabel/luks
```

### Fallback to a Manual Password

If the TPM2 fails (booting on different hardware, a firmware update, a Secure Boot change), the system will automatically prompt for the LUKS password as a fallback. **Always keep the recovery password somewhere safe.**

## 🔍 Fingerprint Sensor (barbudus)

barbudus uses the Goodix 538d sensor (USB `27c6:538d`), supported by the
`lbssousa/libfprint` fork (branch `goodix-538d-sigfm-gtls`, based on libfprint 1.94.10).
The `libfprint-goodix` and `fprintd-goodix` packages are already declared in
`pkgs/libfprint-goodix/` and `pkgs/fprintd-goodix/` and enabled in
`hosts/barbudus/configuration.nix` — no manual configuration is needed after
installation.

To enroll and test a fingerprint:

```bash
# Enroll a fingerprint (runs fprintd-enroll for the current user)
fprintd-enroll

# Verify the enrollment
fprintd-verify

# List devices recognized by fprintd
fprintd-list "$USER"
```

## 📝 Post-installation

### Configure nix-keys for Home Manager

The `abutre` user's Home Manager activation script automatically copies the
personal age key from `$(xdg-user-dir PROJECTS)/lbssousa/nix-keys/sops/age/abutre/keys.txt`
to `~/.config/sops/age/keys.txt`. For this to work on the first `just switch`,
the `nix-keys` repository needs to be cloned and unlocked in the projects directory:

```bash
# Clone nix-keys into the user's projects directory
NIX_KEYS_DIR="$(xdg-user-dir PROJECTS)/lbssousa/nix-keys"
git clone git@github.com:lbssousa/nix-keys.git "$NIX_KEYS_DIR"

# Unlock via GPG (YubiKey)
gpg --card-status               # verify the YubiKey is recognized
cd "$NIX_KEYS_DIR"
git-crypt unlock

# Apply NixOS + Home Manager — the activation script will copy the personal age key automatically
cd /etc/nixos
just switch
```

If the personal age key isn't available at the time of `just switch`, the
activation script will print a warning saying to clone and unlock nix-keys.
Home Manager secrets (like rclone credentials) won't work until the key
is restored.

### Update the system

```bash
# Update flake.lock (all inputs)
cd /etc/nixos
sudo nix flake update

# Rebuild the system
sudo nixos-rebuild switch --flake /etc/nixos#barbudus  # or bigodon
```

### Check the system

```bash
# See Btrfs subvolumes and disk usage
sudo btrfs subvolume list /nix
sudo btrfs filesystem usage /nix

# See tmpfs root usage
df -h /

# See active swap
swapon --show
zramctl

# See Flatpak status
flatpak list --system

# See Podman containers
podman system info
```

### Manual Btrfs Snapshots

```bash
# Snapshot the home subvolume
sudo btrfs subvolume snapshot /home /.snapshots/home-$(date +%Y%m%d-%H%M%S)

# Snapshot persist (critical data)
sudo btrfs subvolume snapshot /persist /.snapshots/persist-$(date +%Y%m%d-%H%M%S)

# Snapshot nix (optional, large)
sudo btrfs subvolume snapshot /nix /.snapshots/nix-$(date +%Y%m%d-%H%M%S)

# List snapshots
sudo btrfs subvolume list /.snapshots

# Remove an old snapshot
sudo btrfs subvolume delete /.snapshots/home-20240101-120000
```

> **Note:** There's no need to snapshot `/` — the root is a tmpfs that's always
> reset clean on every boot. Only `/home`, `/persist` and `/nix` need backups.

## 🔧 Troubleshooting

### System doesn't boot after the initial setup

If the system doesn't boot the first time after disko:

```bash
# Boot from the live USB
# Open LUKS
sudo cryptsetup open /dev/nvme0n1p2 crypted

# Activate LVM
sudo vgchange -ay

# Mount Btrfs subvolumes manually
sudo mount /dev/nvme0n1p1 /mnt/boot
sudo mount -t btrfs -o subvol=@nix /dev/root_vg/root /mnt/nix
sudo mount -t btrfs -o subvol=@persist /dev/root_vg/root /mnt/persist
sudo mount -t btrfs -o subvol=@home /dev/root_vg/root /mnt/home

# Enter the system
sudo nixos-enter --root /mnt
```

### Check Btrfs

```bash
# Filesystem status
sudo btrfs filesystem show /
sudo btrfs device stats /

# Check integrity (scrub)
sudo btrfs scrub start /
sudo btrfs scrub status /

# Compression stats
sudo compsize /
sudo compsize /home
```

### LUKS Issues

```bash
# List LUKS containers
sudo cryptsetup status crypted

# Check the LUKS header
sudo cryptsetup luksDump /dev/nvme0n1p2
```

### Register the YubiKey after the first boot

If step 10 was skipped during installation, `sudo`, `run0` and `pkexec` keep
working via password (PAM automatically falls back to password authentication
when there's no valid U2F mapping). To enable YubiKey authentication after boot:

**Normal option — via password (simplest path)**

With the system running and the YubiKey inserted, use the password to authenticate `run0`:

```bash
pamu2fcfg -u your-username | run0 tee /persist/etc/u2f-mappings
# Touch the YubiKey when its LED blinks
pamu2fcfg -u other-user | run0 tee -a /persist/etc/u2f-mappings  # additional users
```

**Option A — Emergency mode**

Only needed if the account has no valid password. In the systemd-boot menu (hold
**Space** during boot), press **e** on the desired entry and append to the end
of the `options` line:

```
systemd.unit=emergency.target
```

This provides a root shell without authentication. With the YubiKey inserted:

```bash
pamu2fcfg -u your-username > /persist/etc/u2f-mappings
pamu2fcfg -u other-user >> /persist/etc/u2f-mappings  # if there's more than one
```

Reboot normally after creating the file.

> **barbudus (Secure Boot/Limine)**: the boot menu editor is disabled
> when Secure Boot is active. Use Option B.

**Option B — Live ISO**

Boot from the NixOS USB, mount the `@persist` Btrfs subvolume and create the file:

```bash
sudo cryptsetup open /dev/nvme0n1p2 crypted
sudo vgchange -ay
sudo mount -t btrfs -o subvol=@persist /dev/root_vg/root /mnt
pamu2fcfg -u your-username | sudo tee /mnt/etc/u2f-mappings
pamu2fcfg -u other-user | sudo tee -a /mnt/etc/u2f-mappings
sudo umount /mnt
```

After either option, reboot normally and check:

```bash
cat /persist/etc/u2f-mappings  # should show one line per user
run0 id                        # should show uid=0(root)
```

## 📚 References

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Disko](https://github.com/nix-community/disko)
- [Preservation](https://github.com/nix-community/preservation)
- [Home Manager](https://github.com/nix-community/home-manager)
- [Limine Bootloader](https://github.com/limine-bootloader/limine)
- [Btrfs on NixOS](https://nixos.wiki/wiki/Btrfs)
- [Arch Wiki — Btrfs](https://wiki.archlinux.org/title/Btrfs)
- [Erase Your Darlings (ephemeral system)](https://grahamc.com/blog/erase-your-darlings/)
