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
#   6. Configure a usable pinentry for the gpg-agent (fallback: a dynamic
#      pinentry that reads the card PIN via a hidden prompt). Without this,
#      PIN entry fails in headless/live-ISO sessions and git-crypt unlock
#      hangs with a silent "No pinentry".
#   7. Set ultimate trust for the imported key
#   8. Verify the stubs were created and the key is ready to use
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
#
# Pinentry:
#   In a headless / live-ISO session (no interactive TTY), the standard
#   graphical/curses pinentrys cannot open a window and git-crypt unlock hangs
#   with a silent "No pinentry". This script detects that case and installs a
#   small dynamic pinentry that answers the card PIN directly.
#
#   The PIN is obtained as follows (first one that applies):
#     1. $$YUBIKEY_PIN environment variable
#     2. interactive hidden prompt (when a TTY is available)
#     3. one line read from stdin (when no TTY is available)

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
# Pinentry helpers
#
# In headless / live-ISO environments there is usually no graphical pinentry
# (pinentry-gtk/gnome3/curses may not be able to open a window or a usable
# TTY). The gpg-agent talks to a pinentry through the Assuan protocol: after
# launching it, the agent waits for an initial "OK" banner before sending any
# command. If the pinentry doesn't emit that banner, the agent blocks forever
# and `git-crypt unlock` hangs with a silent "No pinentry".
#
# When a suitable pinentry isn't available, we install a tiny dynamic
# pinentry that reads the card PIN from a user-supplied file and answers
# GETPIN with it. The PIN is collected once (interactive prompt) and cached
# by gpg-agent, so the fake pinentry is only needed for the very first
# operation — afterwards the agent releases it.
# ---------------------------------------------------------------------------

# Identifies a pinentry binary that can actually run in the current session.
_pinentry_usable() {
  local bin_dir="$1" cand=""

  # 1) Ask gpgconf for the pinentry it would use.
  if gpgconf --list-dirs >/dev/null 2>&1; then
    cand="$(gpgconf --list-dirs 2>/dev/null | sed -n 's/^pinentry://p')"
    if [[ -n "$cand" && -x "$cand" ]]; then
      echo "$cand"
      return 0
    fi
  fi

  # 2) Look directly in the GNUPG bin dir (some installs ship pinentry there).
  # shellcheck disable=SC2010,SC2045
  for file in "${bin_dir}"/pinentry*; do
    if [[ -x "$file" ]]; then
      echo "$file"
      return 0
    fi
  done

  # 3) Fall back to a known pinentry on PATH.
  local name
  for name in pinentry-curses pinentry-tty pinentry-gnome3 pinentry-gtk-2 pinentry-qt pinentry; do
    if command -v "$name" >/dev/null 2>&1; then
      command -v "$name"
      return 0
    fi
  done

  # 4) Last resort: scan the Nix store for the first pinentry binary.
  local store_hit
  store_hit="$(find /nix/store -maxdepth 4 -type f -path '*/bin/pinentry*' 2>/dev/null | head -1)"
  if [[ -n "$store_hit" && -x "$store_hit" ]]; then
    echo "$store_hit"
    return 0
  fi

  return 1
}

_write_fake_pinentry() {
  local script_path="$1" pin_file="$2"
  local bash_bin
  bash_bin="$(command -v bash || echo /bin/sh)"
  # Resolve stdbuf/awk to absolute paths so the fake pinentry keeps working
  # even if the gpg-agent runs with a reduced PATH.
  local stdbuf_bin
  stdbuf_bin="$(command -v stdbuf || echo stdbuf)"
  cat > "$script_path" <<EOF
#!$bash_bin
# Auto-generated by import-gpg-yubikey.sh — dynamic pinentry for headless GPG.
PIN_FILE="$pin_file"
export PINENTRY_AWK="$AWK_BIN"
export PINENTRY_STDBUF="$stdbuf_bin"
exec "$stdbuf_bin" -oL -eL "$AWK_BIN" -v pinfile="\$PIN_FILE" '
BEGIN {
  while ((getline pin < pinfile) > 0) { }
  close(pinfile)
  print "OK Pleased to meet you"
  fflush()
}
{
  line = \$0
  if (line == "GETPIN") {
    print "D " pin
    fflush()
    print "OK"
    fflush()
  } else if (line == "BYE") {
    print "OK"
    fflush()
    exit 0
  } else {
    print "OK"
    fflush()
  }
}
'
EOF
  chmod 700 "$script_path"
}

# Sets up a usable pinentry for the gpg-agent so that PIN entry (and thus
# git-crypt unlock) works even in a headless / live-ISO session.
_setup_pinentry() {
  local gnupg_home="$1"
  local run_dir="$2"

  mkdir -p "$gnupg_home"
  chmod 700 "$gnupg_home"

  # A system pinentry is only useful when a real interactive TTY is available
  # to show the prompt. In a headless session (no TTY) the graphical/curses
  # pinentrys cannot open a window — even a stray DISPLAY is no guarantee a
  # window server is reachable — so the agent would hang with a silent
  # "No pinentry". In that case we always fall through to the dynamic
  # pinentry below.
  local has_tty=false
  if [[ -t 0 ]] || { tty -s 2>/dev/null; }; then
    has_tty=true
  fi

  local system_pinentry=""
  if [[ "$has_tty" == "true" ]]; then
    system_pinentry="$(_pinentry_usable "$run_dir" || true)"
  fi

  if [[ -n "$system_pinentry" ]]; then
    printf 'pinentry-program %s\n' "$system_pinentry" > "$gnupg_home/gpg-agent.conf"
    info "Using system pinentry: $system_pinentry"
    return 0
  fi

  info "No usable pinentry for the current session — installing a dynamic one (PIN gathered via prompt)."

  local awk_bin
  if command -v gawk >/dev/null 2>&1; then
    awk_bin="$(command -v gawk)"
  elif command -v awk >/dev/null 2>&1; then
    awk_bin="$(command -v awk)"
  else
    warn "Could not locate an awk implementation for the dynamic pinentry."
    return 1
  fi
  AWK_BIN="$awk_bin"

  # Where the fake pinentry and its PIN file will live. /tmp may be insufficient
  # on some live ISOs; ~/.cache is per-user and persists for the session.
  local pin_dir
  pin_dir="${XDG_CACHE_HOME:-$HOME/.cache}/yubikey-gpg-import"
  mkdir -p "$pin_dir"
  chmod 700 "$pin_dir"

  local pin_script="$pin_dir/pinentry"
  local pin_file="$pin_dir/pin"

  # If a previous run left a stale PIN/pinentry behind, drop it so we never
  # reuse an outdated (e.g. since-changed) card PIN.
  rm -f "$pin_script" "$pin_file"

  # Collect the card PIN. Prefer a non-interactive source if the session has
  # no TTY; otherwise prompt (hidden input). Empty input aborts.
  local _card_pin="${YUBIKEY_PIN:-}"
  if [[ -z "$_card_pin" ]]; then
    echo
    echo -e "${BOLD}The card's decryption PIN is required to unlock git-crypt.${RESET}"
    if [[ -t 0 ]] || tty -s 2>/dev/null; then
      read -r -s -p "${CYAN}Carte PIN:${RESET} " _card_pin
      echo
    else
      read -r _card_pin
    fi
  fi
  if [[ -z "$_card_pin" ]]; then
    die "No PIN provided — aborting. Rerun the script and type the card PIN, or export YUBIKEY_PIN."
  fi

  umask 077
  printf '%s\n' "$_card_pin" > "$pin_file"
  _card_pin=""

  _write_fake_pinentry "$pin_script" "$pin_file"

  printf 'pinentry-program %s\n' "$pin_script" > "$gnupg_home/gpg-agent.conf"
  success "Dynamic pinentry installed: $pin_script"
  return 0
}

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

Pinentry (headless / live ISO):
  In a session without an interactive TTY, the standard pinentry can't open
  a window and git-crypt unlock hangs with a silent "No pinentry". This
  script installs a small dynamic pinentry that answers the card PIN.
  The PIN is read in this order:
    1. $$YUBIKEY_PIN environment variable
    2. interactive hidden prompt (when a TTY is available)
    3. one line from stdin (when no TTY is available)

Examples:
  # Default usage (imports from GitHub user lbssousa):
  yubikey-gpg-import

  # With a local public key file:
  yubikey-gpg-import --pubkey /mnt/usb/pubkey.asc

  # Keyserver only, no GitHub:
  yubikey-gpg-import --github "" --keyserver keys.openpgp.org

  # Provide the card PIN non-interactively (e.g. CI / headless):
  YUBIKEY_PIN="<your-card-pin>" yubikey-gpg-import

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
# Step 6: Set up a usable pinentry (so git-crypt unlock works)
# ---------------------------------------------------------------------------

info "==> Step 6: Configure pinentry"

# Resolve the bin dir that holds the pinentry binaries shipped with this
# store, in case gpgconf can't find one yet (e.g. fresh live ISO).
_run_dir=""
if command -v dirname >/dev/null 2>&1; then
  _agent_bin="$(command -v gpg-agent 2>/dev/null || true)"
  if [[ -n "$_agent_bin" ]]; then
    _run_dir="$(dirname "$_agent_bin")"
  fi
fi

_setup_pinentry "$_gnupg_home" "$_run_dir" || warn "Pinentry setup incomplete — git-crypt unlock may still prompt for a PIN on a TTY/terminal."

# Restart the gpg-agent so it reloads gpg-agent.conf (picks up the pinentry).
# Wrap in timeout: killing the agent can hang if it's blocked on a card op.
if command -v timeout >/dev/null 2>&1; then
  timeout 15 gpgconf --kill gpg-agent 2>/dev/null || true
else
  gpgconf --kill gpg-agent 2>/dev/null || true
fi
if command -v gpgconf >/dev/null 2>&1; then
  gpgconf --launch gpg-agent 2>/dev/null || true
fi
success "gpg-agent restarted with the configured pinentry."
echo

# ---------------------------------------------------------------------------
# Step 7: Set ultimate trust
# ---------------------------------------------------------------------------

if [[ "$OPT_NO_TRUST" == "false" ]]; then
  info "==> Step 7: Set ultimate trust for the key"

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
# Step 8: Final verification
# ---------------------------------------------------------------------------

info "==> Step 8: Final verification"
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
info "The pinentry is configured and gpg-agent is running, so PIN entry"
info "works even in a headless session. The key is ready to use:"
echo "  cd /path/to/nix-keys && git-crypt unlock"
echo
info "The PIN was cached by gpg-agent, so the first unlock will not prompt again."
info "If a dynamic pinentry was installed, remember it stores the PIN at:"
echo "  ${XDG_CACHE_HOME:-$HOME/.cache}/yubikey-gpg-import/pin"
echo "  Remove it after unlocking (or keep ~/.gnupg/.cache well protected):"
echo "  rm -rf \"${XDG_CACHE_HOME:-$HOME/.cache}/yubikey-gpg-import\""
echo
echo "  On the live ISO, before installation, bash scripts/install.sh also"
echo "  runs git-crypt unlock automatically via GPG once this step is done."
echo
