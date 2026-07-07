#!/usr/bin/env bash
# import-ssh-yubikey.sh — Import resident SSH keys from the YubiKey on the live CD
#
# Downloads the resident SSH keys (ED25519-SK) stored on the YubiKey to
# ~/.ssh/, making them available for SSH authentication (GitHub, GitLab,
# server access, etc.) during the NixOS installation.
#
# Steps performed:
#   1. Check prerequisites (ssh-keygen, YubiKey detected via USB)
#   2. Download resident keys with ssh-keygen -K
#   3. Move the keys to ~/.ssh/ and set permissions
#   4. Load the keys into ssh-agent (if available)
#   5. Show the imported public keys for verification
#
# Usage:
#   bash scripts/import-ssh-yubikey.sh [options]
#
# Options:
#   --ssh-dir <dir>   Destination directory for the keys (default: ~/.ssh)
#   --no-agent        Don't try to load the keys into ssh-agent
#   --help, -h        Show help and exit
#
# After a successful run, the keys can be used to clone repositories via
# SSH (e.g. nix-keys), which install.sh needs.

set -euo pipefail

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

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

OPT_SSH_DIR="$HOME/.ssh"
OPT_NO_AGENT=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ssh-dir)  OPT_SSH_DIR="$2"; shift 2 ;;
    --no-agent) OPT_NO_AGENT=true; shift ;;
    --help|-h)
      cat <<'EOF'
Usage:
  bash scripts/import-ssh-yubikey.sh [options]

Options:
  --ssh-dir <dir>   Destination directory for the keys (default: ~/.ssh)
  --no-agent        Don't load the keys into ssh-agent after importing
  --help, -h        Show this help and exit

Description:
  Downloads the resident SSH keys (ED25519-SK) from the YubiKey and installs
  them into ~/.ssh/ with the correct permissions. These are "resident" keys:
  the private key material lives on the YubiKey and only a stub is saved to
  disk. So any private-key operation requires the YubiKey to be physically present.

  The script uses ssh-keygen -K, which prompts for the YubiKey PIN interactively.

Examples:
  # Default usage (imports into ~/.ssh/):
  bash scripts/import-ssh-yubikey.sh

  # Alternate destination:
  bash scripts/import-ssh-yubikey.sh --ssh-dir /tmp/ssh-keys
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
echo -e "${BOLD}║       Import resident SSH keys from YubiKey — live CD        ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
echo

# ---------------------------------------------------------------------------
# Step 1: Check prerequisites
# ---------------------------------------------------------------------------

info "==> Step 1: Check prerequisites"

if ! command -v ssh-keygen >/dev/null 2>&1; then
  error "ssh-keygen not found."
  warn "Run before continuing:"
  warn "  nix-shell -p openssh"
  die "ssh-keygen not found."
fi
success "ssh-keygen: $(ssh-keygen -V 2>&1 | head -1 || echo 'available')"

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
# Step 2: Download resident keys with ssh-keygen -K
# ---------------------------------------------------------------------------

info "==> Step 2: Download resident SSH keys from the YubiKey"
echo

# ssh-keygen -K writes the files to the current directory; we use a
# temporary directory to later move them to the final destination.
_tmpdir=$(mktemp -d)
trap 'rm -rf "$_tmpdir"' EXIT

info "You'll be prompted for the YubiKey PIN next."
echo

# ssh-keygen -K:
#   Reads all resident keys from the FIDO authenticator and writes
#   id_ed25519_sk_rk[_<handle>] and id_ed25519_sk_rk[_<handle>].pub files
#   to the CWD. The _rk suffix means "resident key" (a key whose private
#   material lives on the hardware and never leaves the device).
if ! (cd "$_tmpdir" && ssh-keygen -K); then
  echo
  error "ssh-keygen -K failed."
  warn "Possible causes:"
  warn "  • No resident key enrolled on the YubiKey"
  warn "  • Wrong or cancelled PIN"
  warn "  • YubiKey removed during the operation"
  die "Failed to download resident keys from the YubiKey."
fi
echo

# Check whether any key was generated
_key_count=$(find "$_tmpdir" -name "id_ed25519_sk_rk*" ! -name "*.pub" | wc -l)
if [[ "$_key_count" -eq 0 ]]; then
  die "No resident key found on the YubiKey."
fi
info "$_key_count resident key(s) found."
echo

# ---------------------------------------------------------------------------
# Step 3: Move the keys to ~/.ssh/ and set permissions
# ---------------------------------------------------------------------------

info "==> Step 3: Install keys into ${OPT_SSH_DIR}/"

mkdir -p "$OPT_SSH_DIR"
chmod 700 "$OPT_SSH_DIR"

_installed=0
while IFS= read -r _privkey; do
  _pubkey="${_privkey}.pub"
  _basename=$(basename "$_privkey")
  _dst_priv="${OPT_SSH_DIR}/${_basename}"
  _dst_pub="${OPT_SSH_DIR}/${_basename}.pub"

  if [[ -f "$_dst_priv" ]]; then
    warn "File already exists, overwriting: $_dst_priv"
  fi

  cp "$_privkey" "$_dst_priv"
  chmod 600 "$_dst_priv"

  if [[ -f "$_pubkey" ]]; then
    cp "$_pubkey" "$_dst_pub"
    chmod 644 "$_dst_pub"
  fi

  success "Installed: $_dst_priv"
  (( _installed++ )) || true
done < <(find "$_tmpdir" -name "id_ed25519_sk_rk*" ! -name "*.pub" | sort)

echo

# ---------------------------------------------------------------------------
# Step 4: Load the keys into ssh-agent
# ---------------------------------------------------------------------------

if [[ "$OPT_NO_AGENT" == "false" ]]; then
  info "==> Step 4: Load keys into ssh-agent"

  # Start ssh-agent if none is running
  if [[ -z "${SSH_AUTH_SOCK:-}" ]]; then
    info "SSH_AUTH_SOCK not set — starting ssh-agent..."
    eval "$(ssh-agent -s)"
    success "ssh-agent started (PID: $SSH_AGENT_PID)."
    warn "To keep the agent for this session, add to your shell:"
    warn "  eval \"\$(ssh-agent -s)\""
  fi

  _loaded=0
  while IFS= read -r _privkey; do
    _basename=$(basename "$_privkey")
    _dst="${OPT_SSH_DIR}/${_basename}"
    info "Adding to the agent: $_dst"
    if ssh-add "$_dst" 2>/dev/null; then
      success "Added: $_basename"
      (( _loaded++ )) || true
    else
      warn "Failed to add $_basename to the agent (PIN may be required)."
    fi
  done < <(find "$_tmpdir" -name "id_ed25519_sk_rk*" ! -name "*.pub" | sort)

  [[ $_loaded -gt 0 ]] && info "$_loaded key(s) loaded into ssh-agent."
  echo
fi

# ---------------------------------------------------------------------------
# Step 5: Show the imported public keys
# ---------------------------------------------------------------------------

info "==> Step 5: Imported public keys"
echo

while IFS= read -r _pubkey; do
  echo -e "${BOLD}$(basename "$_pubkey"):${RESET}"
  cat "$_pubkey"
  echo
done < <(find "$OPT_SSH_DIR" -name "id_ed25519_sk_rk*.pub" | sort)

echo -e "${GREEN}${BOLD}Resident SSH keys imported successfully!${RESET}"
echo
info "The keys are in: $OPT_SSH_DIR"
info "To check the connection to GitHub:"
echo "  ssh -T git@github.com"
echo
info "Next step — system installation:"
echo "  bash scripts/install.sh"
echo
