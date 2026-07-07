#!/usr/bin/env bash
# inspect-installation.sh — Inspect a NixOS installation made by install.sh
#
# Run this script from a NixOS live environment to check the state of an
# installation already performed by scripts/install.sh.
#
# The script checks:
#   1. System mount at /mnt (Btrfs subvolumes, etc.)
#   2. NixOS installation (Nix store, profiles, bootloader)
#   3. Defined users (/mnt/etc/passwd)
#   4. Password state (/mnt/etc/shadow and /mnt/persist/etc/shadow)
#   5. Flake configuration (/mnt/etc/nixos)
#   6. User files and imports in configuration.nix
#   7. Active bind mounts affecting /mnt/etc/shadow
#
# Usage:
#   bash scripts/inspect-installation.sh [--root <path>] [--mount] [--help]
#
# Options:
#   --root  <path>  Root path of the installed system (default: /mnt)
#   --mount         Try to mount the system before inspecting
#                   (requires the Btrfs subvolumes to be available)
#   --help, -h      Show this help and exit

set -euo pipefail

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

ok()     { echo -e "  ${GREEN}✔${RESET}  $*"; }
fail()   { echo -e "  ${RED}✖${RESET}  $*"; }
warn()   { echo -e "  ${YELLOW}⚠${RESET}  $*"; }
info()   { echo -e "  ${CYAN}ℹ${RESET}  $*"; }
section(){ echo; echo -e "${BOLD}${BLUE}══ $* ══${RESET}"; }

# ---------------------------------------------------------------------------
# Arguments
# ---------------------------------------------------------------------------

ROOT=/mnt
DO_MOUNT=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)  ROOT="$2"; shift 2 ;;
    --mount) DO_MOUNT=true; shift ;;
    --help|-h)
      cat <<'EOF'
Usage:
  bash scripts/inspect-installation.sh [--root <path>] [--mount] [--help]

Options:
  --root <path>  Root path of the installed system (default: /mnt)
  --mount        Try to mount the system before inspecting
  --help, -h     Show this help and exit
EOF
      exit 0 ;;
    *) echo "Unknown option: $1. Use --help to see the available options." >&2; exit 1 ;;
  esac
done

# Requires root for most operations
if [[ $EUID -ne 0 ]]; then
  echo "This script must run as root (use sudo)." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# 0. Optionally mount the system
# ---------------------------------------------------------------------------

if [[ "$DO_MOUNT" == "true" ]]; then
  section "Mounting the installed system at $ROOT"

  # Detect the target device
  if [[ -b /dev/nvme0n1 ]]; then
    DISK=/dev/nvme0n1
  elif [[ -b /dev/sda ]]; then
    DISK=/dev/sda
  else
    warn "Could not auto-detect the disk."
    warn "Mount it manually at $ROOT and run again without --mount."
    exit 1
  fi

  info "Disk detected: $DISK"

  # Unlock LUKS if needed
  if lsblk -o TYPE "$DISK" 2>/dev/null | grep -q crypt; then
    info "LUKS already unlocked."
  elif [[ -b "${DISK}p3" ]] || [[ -b "${DISK}3" ]]; then
    _luks_part="${DISK}p3"
    [[ -b "${DISK}3" ]] && _luks_part="${DISK}3"
    info "Trying to unlock LUKS at $_luks_part..."
    cryptsetup open "$_luks_part" cryptroot || warn "Failed to unlock LUKS."
  fi

  # Mount volume group and Btrfs subvolumes
  if command -v vgchange >/dev/null 2>&1; then
    vgchange -ay 2>/dev/null || true
  fi

  _btrfs_dev=""
  for _candidate in /dev/mapper/vg-root /dev/mapper/cryptroot; do
    if [[ -b "$_candidate" ]]; then
      _btrfs_dev="$_candidate"
      break
    fi
  done
  # Fallback: look for the first available Btrfs device
  if [[ -z "$_btrfs_dev" ]]; then
    _btrfs_dev=$(lsblk -o PATH,FSTYPE --noheadings 2>/dev/null \
      | awk '$2=="btrfs"{print $1; exit}' || true)
  fi

  if [[ -n "$_btrfs_dev" ]]; then
    info "Btrfs device: $_btrfs_dev"
    mkdir -p "$ROOT"
    # The root is tmpfs in the impermanence setup; mount it before the subvolumes
    mount -t tmpfs tmpfs "$ROOT" 2>/dev/null || true
    mkdir -p "$ROOT/nix" "$ROOT/persist" "$ROOT/home"
    mount -o subvol=@nix     "$_btrfs_dev" "$ROOT/nix"     2>/dev/null || true
    mount -o subvol=@persist "$_btrfs_dev" "$ROOT/persist" 2>/dev/null || true
    mount -o subvol=@home    "$_btrfs_dev" "$ROOT/home"    2>/dev/null || true
    # Mount /boot/efi if available
    _efi_part=""
    for _p in "${DISK}p1" "${DISK}1"; do
      [[ -b "$_p" ]] && _efi_part="$_p" && break
    done
    if [[ -n "$_efi_part" ]]; then
      mkdir -p "$ROOT/boot/efi"
      mount "$_efi_part" "$ROOT/boot/efi" 2>/dev/null || true
    fi
    ok "Subvolumes mounted."
  else
    warn "No Btrfs device found. Mount it manually at $ROOT."
  fi
fi

# ---------------------------------------------------------------------------
# 1. Check basic mounts
# ---------------------------------------------------------------------------

section "1. System mount at $ROOT"

_issues=0

_check_dir() {
  local path="$1" label="${2:-$1}"
  if [[ -d "$ROOT$path" ]]; then
    ok "$label exists ($ROOT$path)"
  else
    fail "$label not found ($ROOT$path)"
    ((_issues++)) || true
  fi
}

_check_file() {
  local path="$1" label="${2:-$1}"
  if [[ -f "$ROOT$path" ]]; then
    ok "$label exists ($ROOT$path)"
  else
    fail "$label not found ($ROOT$path)"
    ((_issues++)) || true
  fi
}

_check_dir "" "Root of the installed system"
_check_dir "/nix/store" "Nix store"
_check_dir "/persist" "/persist (Btrfs subvolume)"
_check_dir "/home" "/home (Btrfs subvolume)"
_check_dir "/nix" "/nix (Btrfs subvolume)"

# Check whether it's a tmpfs (root should be tmpfs under impermanence)
if findmnt --target "$ROOT" --output FSTYPE --noheadings 2>/dev/null | grep -q tmpfs; then
  ok "Root ($ROOT) is tmpfs (impermanence active)"
elif findmnt --target "$ROOT" --output FSTYPE --noheadings 2>/dev/null | grep -q btrfs; then
  warn "Root ($ROOT) is Btrfs — tmpfs expected for impermanence"
else
  info "Root filesystem type: $(findmnt --target "$ROOT" --output FSTYPE --noheadings 2>/dev/null || echo 'unknown')"
fi

# Check Btrfs subvolumes
if command -v btrfs >/dev/null 2>&1; then
  _btrfs_root=$(findmnt --target "$ROOT/persist" --output SOURCE --noheadings 2>/dev/null || true)
  if [[ -n "$_btrfs_root" ]]; then
    info "Btrfs subvolumes mounted at $ROOT/persist:"
    btrfs subvolume list "$ROOT/persist" 2>/dev/null | sed 's/^/    /' || true
  fi
fi

# ---------------------------------------------------------------------------
# 2. Check the NixOS installation
# ---------------------------------------------------------------------------

section "2. NixOS installation"

if [[ -L "$ROOT/run/current-system" ]]; then
  _sys="$ROOT/run/current-system"
  ok "System profile: $(readlink -f "$_sys" 2>/dev/null || echo 'unknown')"
elif [[ -L "$ROOT/nix/var/nix/profiles/system" ]]; then
  ok "System profile: $(readlink -f "$ROOT/nix/var/nix/profiles/system" 2>/dev/null)"
else
  fail "NixOS system profile not found"
  ((_issues++)) || true
fi

# Check bootloader
if [[ -d "$ROOT/boot/efi" ]]; then
  ok "/boot/efi mounted"
  if [[ -d "$ROOT/boot/efi/EFI/nixos" ]]; then
    ok "NixOS EFI entries present"
  elif [[ -d "$ROOT/boot/efi/EFI" ]]; then
    warn "EFI directory exists but has no NixOS entries"
  else
    fail "No EFI entry found"
    ((_issues++)) || true
  fi
else
  warn "/boot/efi not mounted (bootloader not inspected)"
fi

# Limine / systemd-boot
if [[ -f "$ROOT/boot/efi/EFI/limine/BOOTX64.EFI" || -f "$ROOT/boot/efi/EFI/BOOT/BOOTX64.EFI" ]]; then
  ok "Limine: bootloader binary present on the ESP"
fi

# Secure Boot keys
if [[ -f "$ROOT/persist/etc/secureboot/GUID" ]]; then
  ok "Secure Boot keys present in /persist/etc/secureboot/"
  info "To enroll them in the firmware: sbctl enroll-keys --microsoft"
else
  info "Secure Boot keys not found in /persist/etc/secureboot/ (this can be normal)"
fi

# ---------------------------------------------------------------------------
# 3. Defined users
# ---------------------------------------------------------------------------

section "3. Defined users (/etc/passwd)"

if [[ -f "$ROOT/etc/passwd" ]]; then
  ok "/etc/passwd found"
  # Show normal users (UID >= 1000, except nobody)
  _normal_users=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1, "(UID=" $3 ")"}' \
    "$ROOT/etc/passwd" || true)
  if [[ -n "$_normal_users" ]]; then
    ok "Normal users defined:"
    echo "$_normal_users" | while read -r _line; do
      info "  → $_line"
    done
  else
    fail "No normal user (UID >= 1000) found in /etc/passwd"
    warn "Check that the user imports are in hosts/*/configuration.nix"
    warn "and that nixos-install completed successfully."
    ((_issues++)) || true
  fi
else
  fail "/etc/passwd not found — NixOS was probably not installed"
  ((_issues++)) || true
fi

# ---------------------------------------------------------------------------
# 4. Password state
# ---------------------------------------------------------------------------

section "4. Password state"

# Helper: decodes the password state from the shadow hash field
_password_status() {
  local hash="$1"
  case "$hash" in
    '!')  echo "locked (no password login)" ;;
    '!!'| '*') echo "not set" ;;
    '$'*) echo "set (hash present)" ;;
    '')   echo "empty (no password — INSECURE)" ;;
    *)    echo "unknown state: $hash" ;;
  esac
}

# --- /mnt/etc/shadow ---
echo
info "==> /mnt/etc/shadow (shadow generated by NixOS activation)"
if [[ -f "$ROOT/etc/shadow" ]]; then
  ok "/etc/shadow found"
  # Check whether it's a bind mount (to /persist/etc/shadow)
  _shadow_mountsrc=$(findmnt --target "$ROOT/etc/shadow" --output SOURCE --noheadings 2>/dev/null || true)
  if [[ -n "$_shadow_mountsrc" ]]; then
    warn "/etc/shadow is bind-mounted from: $_shadow_mountsrc"
    info "This is expected AFTER the first boot (restoreShadow bind-mounts /persist/etc/shadow)."
    info "During installation (before the first boot), /etc/shadow should NOT be bind-mounted."
  fi

  # Show password state for relevant users
  while IFS=: read -r _user _hash _rest; do
    case "$_user" in
      root|nobody|systemd-*|messagebus|polkituser) ;;  # skip system accounts
      *) [[ -z "$_rest" ]] && continue ;;  # skip malformed lines
    esac
    # Show root and normal users
    _uid=$(grep "^${_user}:" "$ROOT/etc/passwd" 2>/dev/null | cut -d: -f3 || echo "")
    if [[ "$_user" == "root" ]] || { [[ -n "$_uid" ]] && [[ "$_uid" -ge 1000 ]] 2>/dev/null; }; then
      info "  $_user: $(_password_status "$_hash")"
    fi
  done < "$ROOT/etc/shadow" 2>/dev/null || true
else
  fail "/etc/shadow not found"
  ((_issues++)) || true
fi

# --- /mnt/persist/etc/shadow ---
echo
info "==> /mnt/persist/etc/shadow (shadow persisted across boots)"
if [[ -f "$ROOT/persist/etc/shadow" ]]; then
  ok "/persist/etc/shadow found"
  _has_password=false
  while IFS=: read -r _user _hash _rest; do
    _uid=$(grep "^${_user}:" "$ROOT/etc/passwd" 2>/dev/null | cut -d: -f3 || echo "")
    if [[ "$_user" == "root" ]] || { [[ -n "$_uid" ]] && [[ "$_uid" -ge 1000 ]] 2>/dev/null; }; then
      _status=$(_password_status "$_hash")
      info "  $_user: $_status"
      [[ "$_hash" == '$'* ]] && _has_password=true
    fi
  done < "$ROOT/persist/etc/shadow" 2>/dev/null || true
  if [[ "$_has_password" == "false" ]]; then
    warn "No user or root has a password set in /persist/etc/shadow."
    warn "Passwords may have been lost. Check step 8 of install.sh."
  fi
else
  fail "/persist/etc/shadow not found"
  warn "Without this file, passwords will be lost on the first boot."
  warn "Run step 8 of install.sh to set passwords and copy the shadow file."
  ((_issues++)) || true
fi

# Compare /etc/shadow and /persist/etc/shadow
if [[ -f "$ROOT/etc/shadow" && -f "$ROOT/persist/etc/shadow" ]]; then
  if cmp -s "$ROOT/etc/shadow" "$ROOT/persist/etc/shadow"; then
    info "/etc/shadow and /persist/etc/shadow are identical (no password diff)"
  else
    _diff=$(diff "$ROOT/etc/shadow" "$ROOT/persist/etc/shadow" 2>/dev/null | head -20 || true)
    if [[ -n "$_diff" ]]; then
      info "/etc/shadow and /persist/etc/shadow differ (expected after setting passwords):"
      echo "$_diff" | sed 's/^/    /'
    fi
  fi
fi

# Password-change flag files
echo
info "==> Password change flag files (/persist/.password-change-required-*)"
_flags=$(ls -1 "$ROOT/persist/.password-change-required-"* 2>/dev/null || true)
if [[ -n "$_flags" ]]; then
  ok "Pre-set password flags found (no forced change on first login):"
  echo "$_flags" | while read -r _f; do
    info "  $_f"
  done
else
  info "No pre-set password flag found."
  info "(Users with initialPassword='nixos' will be forced to change it on 1st login)"
fi

# ---------------------------------------------------------------------------
# 5. Flake configuration (/etc/nixos)
# ---------------------------------------------------------------------------

section "5. Flake configuration (/etc/nixos)"

if [[ -d "$ROOT/etc/nixos" ]]; then
  ok "/etc/nixos exists"

  if [[ -f "$ROOT/etc/nixos/flake.nix" ]]; then
    ok "flake.nix found"
  else
    fail "flake.nix not found in /etc/nixos"
    ((_issues++)) || true
  fi

  if [[ -f "$ROOT/etc/nixos/flake.lock" ]]; then
    ok "flake.lock found"
  else
    warn "flake.lock not found (may cause issues with nixos-rebuild)"
  fi

  # Check the git index
  if [[ -d "$ROOT/etc/nixos/.git" ]]; then
    ok "git repository found at /etc/nixos"
    info "git index status:"
    git -C "$ROOT/etc/nixos" status --short 2>/dev/null | sed 's/^/    /' \
      || info "    (could not get status)"
    # List staged files (in the index)
    info "Files in the git index (staged):"
    git -C "$ROOT/etc/nixos" ls-files 2>/dev/null | grep -E '^(private/users/|hosts/)' \
      | sed 's/^/    /' \
      || info "    (could not list)"
  else
    warn ".git not found at /etc/nixos — Nix will evaluate it as a plain directory"
    info "(All present files will be included in the flake evaluation)"
  fi
else
  fail "/etc/nixos not found"
  ((_issues++)) || true
fi

# ---------------------------------------------------------------------------
# 6. User files and imports in configuration.nix
# ---------------------------------------------------------------------------

section "6. User files and imports"

# Detect available hosts
_hosts=()
if [[ -d "$ROOT/etc/nixos/hosts" ]]; then
  while IFS= read -r _h; do
    _hosts+=("$_h")
  done < <(ls -1 "$ROOT/etc/nixos/hosts/" 2>/dev/null || true)
fi

if [[ ${#_hosts[@]} -eq 0 ]]; then
  warn "No host found in /etc/nixos/hosts/"
else
  info "Available hosts: ${_hosts[*]}"
fi

# Check user files in /etc/nixos/private/users/
echo
info "==> User files in /etc/nixos/private/users/"
_user_files=$(ls -1 "$ROOT/etc/nixos/private/users/"*.nix 2>/dev/null \
  | grep -v "skeleton.nix" || true)
if [[ -n "$_user_files" ]]; then
  ok "User files found:"
  echo "$_user_files" | while read -r _f; do
    _fname=$(basename "$_f")
    _username="${_fname%.nix}"
    # Check whether it's in the git index
    if [[ -d "$ROOT/etc/nixos/.git" ]]; then
      if git -C "$ROOT/etc/nixos" ls-files --error-unmatch "private/users/$_fname" &>/dev/null; then
        info "  ✔ private/users/$_fname (indexed in git — visible to Nix)"
      else
        fail "  ✖ private/users/$_fname (NOT indexed in git — invisible to Nix!)"
        warn "    Run: git -C $ROOT/etc/nixos add --force private/users/$_fname"
        ((_issues++)) || true
      fi
    else
      info "  → private/users/$_fname"
    fi
    # Check whether the user is in /etc/passwd
    if grep -q "^${_username}:" "$ROOT/etc/passwd" 2>/dev/null; then
      info "    └─ user '$_username' present in /etc/passwd ✔"
    else
      warn "    └─ user '$_username' NOT found in /etc/passwd"
      warn "       The import may be missing from configuration.nix, or nixos-install failed."
    fi
  done
else
  warn "No user file found in /etc/nixos/private/users/"
  info "(Only private/users/skeleton.nix found, or the directory is empty)"
fi

# Check imports in each host's configuration.nix
echo
for _host in "${_hosts[@]}"; do
  _cfgfile="$ROOT/etc/nixos/hosts/$_host/configuration.nix"
  if [[ ! -f "$_cfgfile" ]]; then
    continue
  fi
  info "==> User imports in hosts/$_host/configuration.nix:"
  _user_imports=$(grep -E '^\s+\.\/\.\.\/(\.\.\/)?private/users/[^.]+\.nix' "$_cfgfile" 2>/dev/null || true)
  _placeholder=$(grep -E '#.*seu-usuario\.nix|#.*<seu-usuario>' "$_cfgfile" 2>/dev/null || true)
  if [[ -n "$_user_imports" ]]; then
    ok "User imports found:"
    echo "$_user_imports" | while read -r _line; do
      info "  $_line"
    done
  elif [[ -n "$_placeholder" ]]; then
    fail "Only a commented-out placeholder found (no user imported):"
    echo "$_placeholder" | while read -r _line; do
      warn "  $_line"
    done
    warn "install.sh should have replaced the placeholder with the real import."
    ((_issues++)) || true
  else
    warn "No user import found in hosts/$_host/configuration.nix"
  fi
done

# ---------------------------------------------------------------------------
# 7. Active bind mounts on /etc/shadow
# ---------------------------------------------------------------------------

section "7. Bind mounts on /mnt/etc/shadow"

_shadow_mount=$(findmnt --target "$ROOT/etc/shadow" --output SOURCE,TARGET,FSTYPE --noheadings \
  2>/dev/null || true)
if [[ -n "$_shadow_mount" ]]; then
  warn "ACTIVE bind mount on $ROOT/etc/shadow:"
  echo "  $_shadow_mount"
  warn "This means nixos-install's 'restoreShadow' activation script"
  warn "propagated the bind mount into the live CD's namespace."
  warn ""
  warn "WARNING: If you set passwords now with nixos-enter, they'll be written to"
  warn "/mnt/persist/etc/shadow via the bind mount. But install.sh's final command"
  warn "  install -m 640 /mnt/etc/shadow /mnt/persist/etc/shadow"
  warn "would use /mnt/etc/shadow (= /mnt/persist/etc/shadow via the bind mount) as the"
  warn "source, which would be correct in that case. Use passwd --root /mnt to avoid ambiguity."
else
  ok "No active bind mount on $ROOT/etc/shadow (expected state before the 1st boot)"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

section "Summary"

if [[ "$_issues" -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}✔ No issues detected.${RESET}"
  echo "  The installation looks to be in good shape."
else
  echo -e "${RED}${BOLD}✖ ${_issues} issue(s) found.${RESET}"
  echo "  Check the items marked with ✖ or ⚠ above."
fi

echo
echo -e "${BOLD}Common next steps:${RESET}"
echo "  • If passwords haven't been set:"
echo "      passwd --root /mnt <user>"
echo "      passwd --root /mnt root"
echo "      install -m 640 /mnt/etc/shadow /mnt/persist/etc/shadow"
echo "  • If user files aren't indexed:"
echo "      git -C /mnt/etc/nixos add private/users/<user>.nix"
echo "      nixos-install --flake /mnt/etc/nixos#<host>"
echo "  • If the system hasn't been installed yet:"
echo "      bash scripts/install.sh"
echo "  • To unmount and reboot:"
echo "      umount -R /mnt && reboot"
echo
