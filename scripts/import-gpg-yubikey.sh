#!/usr/bin/env bash
# import-gpg-yubikey.sh — Import and trust the GPG key from a YubiKey
#
# Prepares the GPG environment to work with the private key stored on the
# YubiKey. Every step is idempotent (checks before acting), so this runs
# equally well in two contexts:
#   - The live NixOS ISO, before installation — needed to unlock the
#     nix-keys repository via git-crypt (this flake's packages aren't
#     buildable yet at that point, so it has to be a plain script, not a
#     Nix package). Invoke directly: bash scripts/import-gpg-yubikey.sh
#   - An already-installed, already-configured system — pcscd/scdaemon are
#     already set up there (modules/system/security/yubikey.nix,
#     modules/home/apps/security/yubikey.nix), so most steps just confirm
#     that and move on. This is also packaged as the `yubikey-gpg-import`
#     command (pkgs/yubikey-gpg-import/package.nix reads this exact file —
#     single source of truth, no duplicated logic).
#
# Steps performed:
#   1. Check prerequisites (gpg, YubiKey detected via USB)
#   2. Start pcscd if it isn't running
#   3. Configure scdaemon to use PC/SC (disable-ccid), avoiding conflicts with pcscd
#   4. Import the GPG public key: local file > GitHub > keyserver
#   5. Run gpg --card-status to create the private key stubs
#   6. Set ultimate trust for the imported key
#   7. Verify the stubs were created and the key is ready to use
#
# Usage:
#   bash scripts/import-gpg-yubikey.sh [options]
#   yubikey-gpg-import [options]                 (already-installed system)
#
# Options:
#   --fingerprint <fp>  GPG key fingerprint (default: BAC0B1B569777A733E37447FB10712C404063D38)
#   --pubkey <file>     Import the public key from a local file (.asc or binary)
#   --github <user>     Import the public key from a GitHub profile (default: lbssousa)
#   --keyserver <url>   GPG keyserver (default: keyserver.ubuntu.com)
#   --no-trust          Don't set ultimate trust for the imported key
#   --help, -h          Show help and exit

set -euo pipefail

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

DEFAULT_FINGERPRINT="BAC0B1B569777A733E37447FB10712C404063D38"
DEFAULT_GITHUB_USER="lbssousa"
DEFAULT_KEYSERVER="keyserver.ubuntu.com"
YUBICO_USB_VENDOR="1050"

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

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

OPT_FINGERPRINT="$DEFAULT_FINGERPRINT"
OPT_PUBKEY=""
OPT_GITHUB="$DEFAULT_GITHUB_USER"
OPT_KEYSERVER="$DEFAULT_KEYSERVER"
OPT_NO_TRUST=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fingerprint) OPT_FINGERPRINT="$2"; shift 2 ;;
    --pubkey)      OPT_PUBKEY="$2";      shift 2 ;;
    --github)      OPT_GITHUB="$2";      shift 2 ;;
    --keyserver)   OPT_KEYSERVER="$2";   shift 2 ;;
    --no-trust)    OPT_NO_TRUST=true;    shift ;;
    --help|-h)
      cat <<'EOF'
Usage:
  bash scripts/import-gpg-yubikey.sh [options]   (live ISO, before installation)
  yubikey-gpg-import [options]                   (already-installed system)

Options:
  --fingerprint <fp>  Full GPG key fingerprint
                      Default: BAC0B1B569777A733E37447FB10712C404063D38
  --pubkey <file>     Path to a public key file (.asc or binary)
  --github <user>     Import the public key from a GitHub profile (default: lbssousa)
                      Pass "" to disable this source
  --keyserver <url>   GPG keyserver (default: keyserver.ubuntu.com)
  --no-trust          Don't set ultimate trust for the key
  --help, -h          Show this help and exit

Public key sources (in priority order):
  1. --pubkey <file>   local file
  2. --github <user>   https://github.com/<user>.gpg
  3. --keyserver <url> gpg --recv-keys <fingerprint>

Examples:
  # Default usage (imports from GitHub user lbssousa):
  yubikey-gpg-import

  # With a local public key file:
  yubikey-gpg-import --pubkey /mnt/usb/pubkey.asc

  # Keyserver only, no GitHub:
  yubikey-gpg-import --github "" --keyserver keys.openpgp.org

After a successful run, the key is ready to use — e.g.:
  cd /path/to/nix-keys && git-crypt unlock

On the live ISO, before installation, bash scripts/install.sh also runs
git-crypt unlock automatically via GPG once this step is done.
EOF
      exit 0 ;;
    *) die "Unknown option: $1. Use --help to see the available options." ;;
  esac
done

# ---------------------------------------------------------------------------
# Header
# ---------------------------------------------------------------------------

echo
echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║          Import GPG key from YubiKey — install prep          ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
echo

# ---------------------------------------------------------------------------
# Step 1: Check prerequisites
# ---------------------------------------------------------------------------

info "==> Step 1: Check prerequisites"

if ! command -v gpg >/dev/null 2>&1; then
  error "gpg not found."
  warn "Run before continuing:"
  warn "  nix-shell -p gnupg"
  die "gpg not found."
fi
success "gpg: $(gpg --version | head -1)"

if command -v lsusb >/dev/null 2>&1; then
  if ! lsusb 2>/dev/null | grep -qi ":${YUBICO_USB_VENDOR}\b\|${YUBICO_USB_VENDOR}:"; then
    die "YubiKey not detected (lsusb found no Yubico device). Insert the YubiKey and try again."
  fi
  _yubikey_line=$(lsusb 2>/dev/null | grep -i "${YUBICO_USB_VENDOR}:" | head -1)
  success "YubiKey detected: $_yubikey_line"
else
  warn "lsusb not available — hardware check skipped."
fi
echo

# ---------------------------------------------------------------------------
# Step 2: Start pcscd
# ---------------------------------------------------------------------------

info "==> Step 2: Start pcscd (PC/SC daemon)"

_pcscd_running=false

if systemctl is-active --quiet pcscd 2>/dev/null; then
  success "pcscd is already running."
  _pcscd_running=true
elif command -v pcscd >/dev/null 2>&1; then
  _started=false
  if systemctl start pcscd 2>/dev/null; then
    _started=true
  elif command -v run0 >/dev/null 2>&1 && run0 systemctl start pcscd 2>/dev/null; then
    _started=true
  elif command -v sudo >/dev/null 2>&1 && sudo systemctl start pcscd 2>/dev/null; then
    _started=true
  fi

  if [[ "$_started" == "true" ]]; then
    # Wait up to 5s for pcscd to become active
    for _i in 1 2 3 4 5; do
      if systemctl is-active --quiet pcscd 2>/dev/null; then
        _pcscd_running=true
        break
      fi
      sleep 1
    done
    if [[ "$_pcscd_running" == "true" ]]; then
      success "pcscd started."
    else
      warn "pcscd started but didn't become active within 5s."
    fi
  else
    warn "Could not start pcscd automatically."
    warn "Try manually: run0 systemctl start pcscd"
  fi
else
  warn "pcscd not found. Run: nix-shell -p pcsclite"
fi
echo

# ---------------------------------------------------------------------------
# Step 3: Configure scdaemon
# ---------------------------------------------------------------------------

info "==> Step 3: Configure scdaemon"

_gnupg_home="${GNUPGHOME:-$HOME/.gnupg}"
mkdir -p "$_gnupg_home"
chmod 700 "$_gnupg_home"

_scdaemon_conf="$_gnupg_home/scdaemon.conf"

if [[ "$_pcscd_running" == "true" ]]; then
  # disable-ccid: redirects scdaemon to use PC/SC (pcscd) instead of
  # accessing USB directly via CCID. Avoids pcscd and scdaemon contending
  # for the same USB device, which would cause "card error" or "no card".
  if ! grep -q "^disable-ccid" "$_scdaemon_conf" 2>/dev/null; then
    echo "disable-ccid" >> "$_scdaemon_conf"
    success "scdaemon.conf: disable-ccid added."
  else
    success "scdaemon.conf: disable-ccid already configured."
  fi
else
  warn "pcscd is not active — disable-ccid not configured."
  warn "If gpg --card-status fails, start pcscd and rerun the script."
fi

# Restart the GPG agent so scdaemon rereads the configuration
gpgconf --kill gpg-agent 2>/dev/null || true
success "gpg-agent restarted."
echo

# ---------------------------------------------------------------------------
# Step 4: Import the GPG public key
# ---------------------------------------------------------------------------

info "==> Step 4: Import the GPG public key"

_key_imported=false

# Check whether the fingerprint is already in the keyring
if gpg --list-keys "$OPT_FINGERPRINT" >/dev/null 2>&1; then
  success "Fingerprint $OPT_FINGERPRINT is already in the keyring — import skipped."
  _key_imported=true
fi

# Source 1: local file
if [[ "$_key_imported" == "false" && -n "$OPT_PUBKEY" ]]; then
  [[ ! -f "$OPT_PUBKEY" ]] && die "--pubkey: file not found: $OPT_PUBKEY"
  info "Importing from local file: $OPT_PUBKEY"
  if gpg --import "$OPT_PUBKEY" 2>&1; then
    success "Public key imported from the file."
    _key_imported=true
  else
    warn "Failed to import from the local file. Trying the next source..."
  fi
fi

# Source 2: GitHub
if [[ "$_key_imported" == "false" && -n "$OPT_GITHUB" ]]; then
  if command -v curl >/dev/null 2>&1; then
    info "Importing from GitHub: https://github.com/${OPT_GITHUB}.gpg"
    if curl -fsSL "https://github.com/${OPT_GITHUB}.gpg" | gpg --import; then
      success "Public key imported from GitHub (${OPT_GITHUB})."
      _key_imported=true
    else
      warn "Failed to import from GitHub. Trying the keyserver..."
    fi
  else
    warn "curl not available — GitHub source skipped."
  fi
fi

# Source 3: keyserver
if [[ "$_key_imported" == "false" ]]; then
  info "Querying the keyserver: $OPT_KEYSERVER"
  info "Fingerprint: $OPT_FINGERPRINT"
  if gpg --keyserver "$OPT_KEYSERVER" --recv-keys "$OPT_FINGERPRINT"; then
    success "Public key obtained from the keyserver."
    _key_imported=true
  else
    die "Could not obtain the public key from any of the configured sources."
  fi
fi

# Confirm the expected fingerprint is in the keyring
if ! gpg --list-keys "$OPT_FINGERPRINT" >/dev/null 2>&1; then
  error "Fingerprint $OPT_FINGERPRINT not found in the keyring after import."
  warn "The imported key may have a different fingerprint."
  warn "List the available keys with: gpg --list-keys"
  die "Fingerprint not found in the keyring."
fi
echo

# ---------------------------------------------------------------------------
# Step 5: Create private key stubs via gpg --card-status
# ---------------------------------------------------------------------------

info "==> Step 5: Create private key stubs (gpg --card-status)"
echo

if ! gpg --card-status; then
  echo
  error "gpg --card-status failed."
  warn "Check:"
  warn "  • YubiKey inserted"
  warn "  • pcscd running: systemctl status pcscd"
  warn "  • scdaemon configuration: cat ~/.gnupg/scdaemon.conf"
  die "Failed to read the YubiKey card."
fi
echo

# ---------------------------------------------------------------------------
# Step 6: Set ultimate trust
# ---------------------------------------------------------------------------

if [[ "$OPT_NO_TRUST" == "false" ]]; then
  info "==> Step 6: Set ultimate trust for the key"

  if echo "${OPT_FINGERPRINT}:6:" | gpg --import-ownertrust; then
    success "Ultimate trust set for $OPT_FINGERPRINT."
  else
    warn "Could not set trust automatically."
    warn "Run manually:"
    warn "  gpg --edit-key $OPT_FINGERPRINT"
    warn "  trust → 5 (I trust ultimately) → quit"
  fi
  echo
fi

# ---------------------------------------------------------------------------
# Step 7: Final verification
# ---------------------------------------------------------------------------

info "==> Step 7: Final verification"
echo

gpg --list-secret-keys --keyid-format long "$OPT_FINGERPRINT" 2>/dev/null \
  || gpg --list-secret-keys --keyid-format long

echo

# Card key stubs show up as sec> or ssb> (the '>' marks a card stub)
if gpg --list-secret-keys "$OPT_FINGERPRINT" 2>/dev/null | grep -qE '^(sec|ssb)>'; then
  success "Key stubs detected (sec> / ssb> — private key on the YubiKey)."
else
  warn "No card stub detected (expected: sec> or ssb>)."
  warn "git-crypt unlock may fail. Check: gpg --list-secret-keys"
fi

echo
echo -e "${GREEN}${BOLD}GPG environment ready to use with the YubiKey!${RESET}"
echo
info "The key is ready to use — for example:"
echo "  cd /path/to/nix-keys && git-crypt unlock"
echo
echo "  On the live ISO, before installation, bash scripts/install.sh also"
echo "  runs git-crypt unlock automatically via GPG once this step is done."
echo
