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
#   3.5 Generate ~/.ssh/config with a Host block per resident key
#       (points IdentityFile at the resident key and bypasses the agent,
#       which otherwise refuses to sign ED25519-SK keys)
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

  A ~/.ssh/config is also generated with one Host block per resident key
  (e.g. Host github.com). It points IdentityFile at the resident key and sets
  IdentitiesOnly yes + IdentityAgent none, so ssh uses the FIDO authenticator
  directly instead of the SSH agent — which typically refuses to sign ED25519-SK
  keys (e.g. gnome-keyring returning 'agent refused operation').

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
# Step 3.5: Generate ~/.ssh/config with a Host block per resident key
# ---------------------------------------------------------------------------
# Resident ED25519-SK keys only work if ssh loads them explicitly:
#
#   - ssh only probes default filenames (id_ed25519_sk, id_rsa, ...), never
#     the *_rk* residents, unless an IdentityFile points to them.
#
#   - Any SSH agent (gnome-keyring, Bitwarden, etc.) that has these keys
#     loaded returns "agent refused operation" when asked to sign them
#     (ED25519-SK must contact the FIDO device directly via the sshsk path).
#     Bypassing the agent with IdentityAgent none + IdentitiesOnly yes makes
#     ssh use the authenticator instead of the agent, prompting for the touch.
#
# The host each key belongs to is embedded in the public key's comment, e.g.
# "ssh:github.com". All keys that resolve to the same host are aggregated into
# a single Host block, so ssh tries each matching IdentityFile in order. This
# yields entries like:
#
#   Host github.com
#     IdentityFile ~/.ssh/id_ed25519_sk_rk_github.com
#     IdentityFile ~/.ssh/id_ed25519_sk_rk_github.com_lbssousa
#     IdentitiesOnly yes
#     IdentityAgent none
#     AddKeysToAgent no

info "==> Step 3.5: Generate ${OPT_SSH_DIR}/config (per-key Host blocks)"

_CONFIG_FILE="${OPT_SSH_DIR}/config"

if [[ -f "$_CONFIG_FILE" ]]; then
  if ! confirm "File $_CONFIG_FILE already exists. Overwrite it?"; then
    warn "Keeping the existing $_CONFIG_FILE (skipping key blocks)."
    info "Add an IdentityFile/IdentitiesOnly/IdentityAgent block manually to use the resident keys."
  else
    _OVERWRITE_CONFIG=true
  fi
else
  _OVERWRITE_CONFIG=true
fi

if [[ "${_OVERWRITE_CONFIG:-false}" == "true" ]]; then
  : > "$_CONFIG_FILE"

  declare -A _host_keys=()

  while IFS= read -r _privkey; do
    _pubkey="${_privkey}.pub"
    _basename=$(basename "$_privkey")

    # The on-disk key name already contains the host (e.g.
    # id_ed25519_sk_rk_github.com); fall back to the pubkey comment if
    # the filename is ambiguous.
    _host=""
    if [[ -f "$_pubkey" ]]; then
      # Format: <keytype> <base64blob> <comment>, comment is "ssh:<host>".
      _comment=$(awk '{ $1=""; $2=""; gsub(/^[ \t]+|[ \t]+$/, ""); print }' "$_pubkey")
      if [[ "$_comment" =~ ^ssh:([^ ]+)$ ]]; then
        _host="${BASH_REMATCH[1]}"
      fi
      # Prefer the host encoded in the filename (more reliable/long-lived).
      if [[ "$_basename" =~ _rk_(.+) ]]; then
        _filename_host="${BASH_REMATCH[1]}"
        # The filename may end with a random hex "key handle" appended by
        # ssh-keygen for per-rp duplicates; strip a trailing _<64hex> so the
        # host is clean.
        _filename_host="${_filename_host%_*}"
        [[ -n "$_filename_host" ]] && _host="$_filename_host"
      fi
    fi

    if [[ -z "$_host" ]]; then
      warn "Could not determine the host for $_basename — skipping its block."
      continue
    fi

    _host_keys["$_host"]+="${_basename}|"
  done < <(find "$_tmpdir" -name "id_ed25519_sk_rk*" ! -name "*.pub" | sort)

  if [[ ${#_host_keys[@]} -eq 0 ]]; then
    warn "No Host block could be generated for $_CONFIG_FILE."
  else
    for _host in "${!_host_keys[@]}"; do
      printf '\nHost %s\n' "$_host" >> "$_CONFIG_FILE"
      IFS='|' read -ra _keys <<< "${_host_keys[$_host]}"
      for _kb in "${_keys[@]}"; do
        [[ -z "$_kb" ]] && continue
        printf '  IdentityFile %s/%s\n' "$OPT_SSH_DIR" "$_kb" >> "$_CONFIG_FILE"
      done
      printf '  IdentitiesOnly yes\n' >> "$_CONFIG_FILE"
      printf '  IdentityAgent none\n' >> "$_CONFIG_FILE"
      printf '  AddKeysToAgent no\n' >> "$_CONFIG_FILE"
      success "Host block generated for '$_host' (${#_keys[@]} key(s))."
    done
    success "$_CONFIG_FILE generated with ${#_host_keys[@]} Host block(s)."
  fi
fi

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
info "A ~/.ssh/config with per-key Host blocks was generated too."
info "To check the connection to GitHub (touch the YubiKey when prompted):"
echo "  ssh -T git@github.com"
echo
info "Next step — system installation:"
echo "  bash scripts/install.sh"
echo
