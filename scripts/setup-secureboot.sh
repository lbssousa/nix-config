#!/usr/bin/env bash
# setup-secureboot.sh — Configure Secure Boot and sign kernel modules (NVIDIA)
#
# This script performs the post-installation steps needed for Secure Boot
# to work with Limine:
#
#   1. Check the current state of Secure Boot and sbctl
#   2. Check the PKI key store (sbctl)
#   3. Sign all EFI binaries BEFORE enrolling them in the firmware
#   4. Verify that all binaries are signed (precondition for enrollment)
#   5. Enroll the PKI keys in the UEFI firmware (sbctl enroll-keys)
#   6. Final signature verification
#
# ⚠️  Run this script AFTER the system's first boot,
#     with Secure Boot DISABLED in the firmware (Setup Mode).
#     After the script, re-enable Secure Boot in the firmware and reboot.
#
# Usage:
#   bash scripts/setup-secureboot.sh [--enroll-only] [--sign-only]
#                                    [--verify-only] [--help]
#
# Options:
#   --enroll-only   Only enrolls the keys in the firmware (no sign/verify)
#   --sign-only     Only signs the pending binaries (no enroll/verify)
#   --verify-only   Only verifies the signatures (no enroll/sign)
#   --help, -h      Show help and exit

set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET} $*"; }
success() { echo -e "${GREEN}[OK]${RESET}   $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET} $*"; }
error()   { echo -e "${RED}[ERRO]${RESET} $*" >&2; }
die()     { error "$*"; exit 1; }

verify_signed_efi_binaries() {
  local _verify_output
  local _verify_exit
  local _unsigned_actionable

  if _verify_output=$(sbctl verify 2>&1); then
    _verify_exit=0
  else
    _verify_exit=$?
  fi
  echo "$_verify_output"

  # On some sbctl versions, the exit code may not reflect pending binaries.
  # So we also validate the textual content of the output.
  if echo "$_verify_output" | grep -Eiq 'is not signed|not signed'; then
    _unsigned_actionable=$(extract_unsigned_efi_paths "$_verify_output")
    if [[ -n "$_unsigned_actionable" ]]; then
      return 1
    fi

    warn "There are non-actionable 'not signed' entries (e.g. non-PE initrd-*.efi); ignoring."
    return 0
  fi

  return $_verify_exit
}

extract_unsigned_efi_paths() {
  local _verify_output="$1"

  # Excludes from the "needs signing" set the artifacts that Limine does
  # NOT verify via PE/Authenticode signature:
  #   • /boot/EFI/nixos/kernel-*.efi and initrd-*.efi: generic NixOS bootspec
  #     artifacts, not used by Limine to boot (the firmware never loads
  #     them directly).
  #   • /boot/limine/kernels/*: the kernel/initrd Limine actually uses.
  #     Their integrity is guaranteed by a BLAKE2B checksum embedded in
  #     limine.conf (boot.loader.limine.validateChecksums), whose hash is
  #     itself embedded in the signed Limine binary (enroll-config) — not
  #     by an individual signature on each file.
  # The only binary that MUST be signed for boot to work is the bootloader
  # itself (/boot/EFI/limine/BOOTX64.EFI), and the Limine installer already
  # signs it automatically on every nixos-rebuild switch/boot.
  echo "$_verify_output" \
    | grep -E 'not signed' \
    | grep -Eo '/[^[:space:]]+\.efi' \
    | grep -Ev '^/boot/EFI/nixos/' \
    | sort -u
}

sign_explicit_efi_path() {
  local _path="$1"
  local _sign_output

  if [[ ! -f "$_path" ]]; then
    warn "EFI file not found for explicit signing: $_path"
    return 1
  fi

  # No file in /boot/EFI/nixos/ should be signed by sbctl:
  #   • kernel-*.efi: a generic NixOS bootspec artifact, not loaded
  #     directly by the firmware under Limine.
  #   • initrd-*.efi: not PE/COFF images, sbctl can't sign them.
  # The bootloader (/boot/EFI/limine/BOOTX64.EFI) is already signed
  # automatically by the Limine installer on every nixos-rebuild switch/boot.
  if [[ "$_path" =~ ^/boot/EFI/nixos/ ]]; then
    warn "Skipping bootspec artifact not used by Limine (should not be signed by sbctl): $_path"
    return 3
  fi

  # Some versions use 'sbctl sign -s <path>', others accept 'sbctl sign <path>'.
  if _sign_output=$(sbctl sign -s "$_path" 2>&1); then
    return 0
  fi

  if echo "$_sign_output" | grep -qi 'unrecognized PE machine'; then
    warn "File is not a signable PE/COFF image: $_path"
    return 3
  fi

  if _sign_output=$(sbctl sign "$_path" 2>&1); then
    return 0
  fi

  if echo "$_sign_output" | grep -qi 'unrecognized PE machine'; then
    warn "File is not a signable PE/COFF image: $_path"
    return 3
  fi

  return 1
}

try_fix_unsigned_efi_binaries() {
  local _verify_output="$1"
  local _unsigned_paths
  local _path
  local _sign_rc
  local _fixed_any=false
  local _failed_any=false

  _unsigned_paths=$(extract_unsigned_efi_paths "$_verify_output")
  if [[ -z "$_unsigned_paths" ]]; then
    return 1
  fi

  warn "Unsigned EFI binaries detected. Trying explicit signing..."
  while IFS= read -r _path; do
    [[ -z "$_path" ]] && continue
    if sign_explicit_efi_path "$_path"; then
      success "Explicit signature applied: $_path"
      _fixed_any=true
    else
      _sign_rc=$?
      if [[ $_sign_rc -eq 3 ]]; then
        warn "File not signable by sbctl (ignored): $_path"
      else
        warn "Failed to sign explicitly: $_path"
        _failed_any=true
      fi
    fi
  done <<< "$_unsigned_paths"

  if [[ "$_fixed_any" == "true" && "$_failed_any" == "false" ]]; then
    return 0
  fi

  if [[ "$_fixed_any" == "true" ]]; then
    return 2
  fi

  return 1
}

# NOTE: The sign_nixos_efi_binaries_explicitly function was removed.
# /boot/EFI/nixos/ contains generic NixOS bootspec artifacts that Limine
# does NOT use to boot (the real kernel/initrd live in
# /boot/limine/kernels/, verified by checksum, not signature), and
# therefore must NOT be manually signed by sbctl:
#   • kernel-*.efi: not loaded by the firmware under Limine.
#   • initrd-*.efi: not PE/COFF, impossible to sign with sbctl.
# The bootloader (/boot/EFI/limine/BOOTX64.EFI) is already signed
# automatically by the Limine installer during nixos-rebuild. Only extra
# bootloaders (e.g. fwupd-efi) may need manual signing via 'sbctl sign-all'.

unlock_efivarfs_immutables() {
  local _efivarfs=/sys/firmware/efi/efivars
  local _had_immutable=false
  local _cleared_any=false
  local _f

  if [[ ! -d "$_efivarfs" ]]; then
    warn "efivarfs is not mounted at $_efivarfs."
    return 1
  fi

  if ! command -v chattr >/dev/null 2>&1; then
    warn "'chattr' not found. Could not unlock immutable EFI variables."
    return 1
  fi

  for _f in \
    "$_efivarfs"/PK-* \
    "$_efivarfs"/KEK-* \
    "$_efivarfs"/db-* \
    "$_efivarfs"/dbx-*; do
    if [ -f "$_f" ]; then
      if lsattr "$_f" 2>/dev/null | awk '{print $1}' | grep -q 'i'; then
        _had_immutable=true
      fi

      # Try to clear the immutable bit idempotently.
      if chattr -i "$_f" 2>/dev/null; then
        _cleared_any=true
      fi
    fi
  done

  if [ "$_had_immutable" = "true" ]; then
    warn "Immutable attribute (chattr +i) detected and cleared on the EFI variables."
    warn "This happens on some firmwares that lock efivars even in Setup Mode."
    echo
  fi

  if [ "$_cleared_any" = "true" ]; then
    return 0
  fi

  return 1
}

# ---------------------------------------------------------------------------
# Ensure running as root
# ---------------------------------------------------------------------------

if [[ $EUID -ne 0 ]]; then
  info "This script must run as root. Re-executing with run0..."
  exec run0 bash "${BASH_SOURCE[0]}" "$@"
fi

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

OPT_ENROLL_ONLY=false
OPT_SIGN_ONLY=false
OPT_VERIFY_ONLY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --enroll-only) OPT_ENROLL_ONLY=true; shift ;;
    --sign-only)   OPT_SIGN_ONLY=true;   shift ;;
    --verify-only) OPT_VERIFY_ONLY=true; shift ;;
    --help|-h)
      cat <<'EOF'
Usage:
  bash scripts/setup-secureboot.sh [--enroll-only] [--sign-only]
                                   [--verify-only] [--help]

Options:
  --enroll-only   Only enrolls the PKI keys in the UEFI firmware
  --sign-only     Only signs the EFI binaries (and verifies before enrolling)
  --verify-only   Only checks whether all binaries are signed
  --help, -h      Show this help and exit

Steps to set up Secure Boot:
  1. Boot the system with Secure Boot DISABLED (Setup Mode in the UEFI)
     (to enable Setup Mode: BIOS → Secure Boot → clear existing keys)
  2. Run this script to sign the binaries and enroll the keys:
       run0 bash scripts/setup-secureboot.sh
     The script:
       a) Signs all EFI binaries with the PKI keys (sign-all)
       b) Verifies that ALL binaries are signed (mandatory)
       c) Enrolls the keys in the UEFI firmware (enroll-keys --microsoft)
  3. Reboot and enable Secure Boot in the UEFI/BIOS
  4. Verify everything is correct:
       run0 bash scripts/setup-secureboot.sh --verify-only

IMPORTANT NOTE — Limine vs. MOK/shim:
  This configuration uses Limine, which does NOT use shim or MOK.
  • There will be no blue MOKmanager screen during boot
  • You won't be asked for a MOK password
  • The absence of MOK is EXPECTED and CORRECT with Limine
  • The firmware only verifies the PE signature of the Limine binary
    (PKI keys PK/KEK/db enrolled in the UEFI firmware via sbctl)
  • Kernel/initrd integrity is guaranteed by a BLAKE2B checksum embedded
    in limine.conf, whose hash is embedded in the signed binary
    (enroll-config) — not by an individual signature on each file
  • On every nixos-rebuild switch/boot, the Limine installer re-signs the
    binary and re-enrolls the checksum of the updated config

Notes:
  • The PKI keys are created automatically during installation (install.sh)
    and live in /persist/etc/secureboot (symlinked from /var/lib/sbctl, see
    systemd.tmpfiles.rules on the host)
  • Limine automatically signs its own binary on every nixos-rebuild
  • Use sbctl verify to check which binaries aren't signed
    (kernel/initrd under /boot/limine/kernels/ show up as "not signed" by
    design — they're verified by checksum, not signature)
EOF
      exit 0 ;;
    *) die "Unknown option: $1. Use --help to see the available options." ;;
  esac
done

# Check that at most one exclusive flag is active
_exclusive_count=0
[[ "$OPT_ENROLL_ONLY" == "true" ]] && (( _exclusive_count++ )) || true
[[ "$OPT_SIGN_ONLY"   == "true" ]] && (( _exclusive_count++ )) || true
[[ "$OPT_VERIFY_ONLY" == "true" ]] && (( _exclusive_count++ )) || true
if [[ $_exclusive_count -gt 1 ]]; then
  die "--enroll-only, --sign-only and --verify-only are mutually exclusive."
fi

echo
echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║              Secure Boot Configuration (Limine)              ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
echo

# ---------------------------------------------------------------------------
# Checks
# ---------------------------------------------------------------------------

if ! command -v sbctl >/dev/null 2>&1; then
  die "sbctl not found. Make sure boot.loader.limine.secureBoot.enable
  is active and the system was rebuilt with 'nixos-rebuild switch'."
fi

# ---------------------------------------------------------------------------
# Step 1: Current state
# ---------------------------------------------------------------------------

info "==> Current Secure Boot state:"
sbctl status || true
echo

# ---------------------------------------------------------------------------
# Step 2: Check the PKI key store
# ---------------------------------------------------------------------------

# Check whether the sbctl key store is accessible.
# The host configuration creates a /var/lib/sbctl → /persist/etc/secureboot
# symlink via systemd-tmpfiles (rule "L+ /var/lib/sbctl"). If the keys
# aren't found, sbctl can't sign binaries or enroll keys in the firmware.
# Uses a filesystem check for robustness (independent of locale/encoding).
_sbctl_db=/var/lib/sbctl
if [[ ! -d "$_sbctl_db/keys" ]] && [[ ! -f "$_sbctl_db/GUID" ]]; then
  error "sbctl key store not found at $_sbctl_db."
  warn "The PKI keys must be at /var/lib/sbctl (→ /persist/etc/secureboot)."
  warn "Check that:"
  warn "  • The installation completed successfully (install.sh created the keys)"
  warn "  • The /var/lib/sbctl → /persist/etc/secureboot symlink exists"
  warn "  • The system was rebuilt with 'nixos-rebuild switch'"
  die "Key store not found. Check the installation."
fi
_sbctl_status_output=$(sbctl status 2>&1)

# ---------------------------------------------------------------------------
# Step 3: Sign EFI binaries BEFORE enrolling them in the firmware
# ---------------------------------------------------------------------------
# Signing before enrolling ensures that, if the signing process fails
# (missing key, invalid binary), the firmware isn't changed unnecessarily.

if [[ "$OPT_ENROLL_ONLY" != "true" && "$OPT_VERIFY_ONLY" != "true" ]]; then
  info "==> Signing EFI binaries with the PKI keys..."
  echo

  if sbctl sign-all; then
    success "All EFI binaries signed."
  else
    warn "Some binaries may not have been signed."
    warn "Run 'sbctl verify' to check which ones are pending."
  fi
  echo

  # Verify signatures BEFORE proceeding with firmware enrollment.
  # If there are unsigned binaries, booting with Secure Boot active will fail.
  info "==> Verifying signatures before firmware enrollment..."
  if _verify_before_enroll_output=$(verify_signed_efi_binaries); then
    echo "$_verify_before_enroll_output"
  else
    echo "$_verify_before_enroll_output"
    echo

    if try_fix_unsigned_efi_binaries "$_verify_before_enroll_output"; then
      echo
      info "==> Revalidating EFI signatures after automatic fix..."
      if ! verify_signed_efi_binaries; then
        echo
        error "There are EFI binaries without a valid signature after the automatic fix attempt."
        warn "Secure Boot will fail if the firmware is configured now."
        warn "Run the following commands to fix it and try again:"
        warn "  1. run0 nixos-rebuild switch   (regenerates and signs the Limine binary)"
        warn "  2. run0 sbctl sign-all         (signs additional binaries)"
        warn "  3. run0 bash scripts/setup-secureboot.sh   (run this script again)"
        die "Incomplete signatures. Fix this before enrolling the keys in the firmware."
      fi
    else
      error "There are EFI binaries without a valid signature."
      warn "Secure Boot will fail if the firmware is configured now."
      warn "Run the following commands to fix it and try again:"
      warn "  1. run0 nixos-rebuild switch   (regenerates and signs the Limine binary)"
      warn "  2. run0 sbctl sign-all         (signs additional binaries)"
      warn "  3. run0 bash scripts/setup-secureboot.sh   (run this script again)"
      die "Incomplete signatures. Fix this before enrolling the keys in the firmware."
    fi
  fi
  success "All EFI binaries are signed. Proceeding with enrollment."
  echo
fi

# ---------------------------------------------------------------------------
# Step 4: Enroll the PKI keys in the UEFI firmware
# ---------------------------------------------------------------------------

if [[ "$OPT_SIGN_ONLY" != "true" && "$OPT_VERIFY_ONLY" != "true" ]]; then
  info "==> Enrolling the PKI keys in the UEFI firmware..."
  echo

  # Check whether the firmware is in Setup Mode (a precondition for enroll-keys)
  # With Limine, there is NO MOK password or MOKmanager screen.
  # Limine uses its own PKI keys (PK/KEK/db) — it doesn't use shim/MOK.
  # Uses an EFI efivars check for robustness (independent of sbctl's locale/encoding).
  _in_setup_mode=false
  # GUID of the global EFI variable (EFI_GLOBAL_VARIABLE) — UEFI Spec Appendix B standard
  _EFI_GLOBAL_GUID="8be4df61-93ca-11d2-aa0d-00e098032b8c"
  # Try checking the content of the SetupMode EFI variable (1 = Setup Mode active)
  if [[ -f /sys/firmware/efi/efivars/SetupMode-${_EFI_GLOBAL_GUID} ]]; then
    # The attribute byte is the first 4 bytes; the value is the 5th byte (0x01 = Setup Mode)
    _setup_byte=$(od -An -tx1 -j4 -N1 \
      /sys/firmware/efi/efivars/SetupMode-${_EFI_GLOBAL_GUID} 2>/dev/null \
      | tr -d ' \n')
    [[ "$_setup_byte" == "01" ]] && _in_setup_mode=true
  fi
  # Fallback: check sbctl's output (patterns without special Unicode characters)
  if [[ "$_in_setup_mode" == "false" ]]; then
    if echo "$_sbctl_status_output" | grep -qi "setup mode[[:space:]]*:.*enabled\|setup mode[[:space:]]*:.*yes"; then
      _in_setup_mode=true
    fi
  fi

  if [[ "$_in_setup_mode" == "false" ]]; then
    error "The firmware is NOT in Setup Mode."
    echo
    warn "To enroll the PKI keys, the firmware needs to be in Setup Mode."
    warn "How to enable Setup Mode:"
    warn "  1. Reboot and enter the BIOS/UEFI (F2, F12, Del or Esc during boot)"
    warn "  2. In the Secure Boot section, look for 'Setup Mode', 'Clear Secure Boot Keys',"
    warn "     'Delete All Secure Boot Keys' or a similar option"
    warn "  3. Clear the existing keys (this enables Setup Mode)"
    warn "  4. Save the settings and reboot the system"
    warn "  5. Run this script again"
    echo
    warn "IMPORTANT NOTE: This configuration uses Limine — it does NOT use shim/MOK."
    warn "There will be no MOKmanager screen or MOK password prompt."
    warn "Limine signs its own binary directly with its own PKI keys."
    echo
    die "Firmware is not in Setup Mode. Fix this and run the script again."
  fi

  success "Firmware in Setup Mode. Proceeding with key enrollment."
  echo

  # Some firmwares mark efivars as immutable even in Setup Mode.
  # Make a preventive attempt to unlock them before enrollment.
  unlock_efivarfs_immutables || true

  warn "The Microsoft keys are included to ensure compatibility with"
  warn "firmware drivers signed by Microsoft (e.g. GPU drivers)."
  echo

  if _enroll_output=$(sbctl enroll-keys --microsoft 2>&1); then
    _enroll_exit=0
  else
    _enroll_exit=$?
  fi
  echo "$_enroll_output"

  if [[ $_enroll_exit -eq 0 ]]; then
    success "PKI keys enrolled in the UEFI firmware."
  else
    if echo "$_enroll_output" | grep -Eiq 'file is immutable|chattr -i files in efivarfs'; then
      warn "Failure detected due to immutable efivars. Trying to unlock and retry enrollment..."
      unlock_efivarfs_immutables || true

      if _retry_output=$(sbctl enroll-keys --microsoft 2>&1); then
        _retry_exit=0
      else
        _retry_exit=$?
      fi
      echo "$_retry_output"

      if [[ $_retry_exit -eq 0 ]]; then
        success "PKI keys enrolled in the UEFI firmware (after unlocking efivars)."
      else
        error "Failed to enroll the PKI keys after the unlock attempt (code: $_retry_exit)."
        warn "Possible causes:"
        warn "  • The firmware did not accept the keys (check Setup Mode in the UEFI)"
        warn "  • The keys were already enrolled previously (run --verify-only)"
        warn "  • Write-restricted UEFI (try sbctl enroll-keys --yes-this-might-brick-my-machine)"
        die "Key enrollment failed. Fix this and try again."
      fi
    else
      error "Failed to enroll the PKI keys (code: $_enroll_exit)."
      warn "Possible causes:"
      warn "  • The firmware did not accept the keys (check Setup Mode in the UEFI)"
      warn "  • The keys were already enrolled previously (run --verify-only)"
      warn "  • Write-restricted UEFI (try sbctl enroll-keys --yes-this-might-brick-my-machine)"
      die "Key enrollment failed. Fix this and try again."
    fi
  fi
  echo
fi

# ---------------------------------------------------------------------------
# Step 5: Final signature verification
# ---------------------------------------------------------------------------

if [[ "$OPT_ENROLL_ONLY" != "true" && "$OPT_SIGN_ONLY" != "true" ]]; then
  info "==> Final EFI binary verification..."
  echo

  if verify_signed_efi_binaries; then
    echo
    success "All EFI binaries are properly signed!"
  else
    echo
    warn "Some EFI binaries are not signed (post-enrollment check)."
    warn "Run 'nixos-rebuild switch' to regenerate and sign the binaries,"
    warn "then run 'run0 sbctl sign-all' to sign the pending ones."
  fi
  echo
fi

# ---------------------------------------------------------------------------
# Final instructions
# ---------------------------------------------------------------------------

if [[ "$OPT_VERIFY_ONLY" != "true" ]]; then
  echo
  echo -e "${GREEN}${BOLD}Secure Boot setup complete!${RESET}"
  echo
  info "Next steps:"
  echo "  1. Reboot the system"
  echo "  2. Enter the UEFI/BIOS and ENABLE Secure Boot"
  echo "  3. Save and reboot again"
  echo "  4. Verify the state with:"
  echo "       run0 sbctl status"
  echo "       run0 bash scripts/setup-secureboot.sh --verify-only"
  echo
  warn "If the system doesn't boot with Secure Boot active, disable it"
  warn "in the UEFI and run this script again."
fi
