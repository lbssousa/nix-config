#!/usr/bin/env bash
# update.sh — Update the NixOS system
#
# Updates the flake inputs and rebuilds the system with nixos-rebuild switch.
#
# Usage:
#   bash scripts/update.sh [--host <hostname>] [--update-only] [--rebuild-only]
#                          [--help]
#
# Options:
#   --host <hostname>   NixOS host name (default: current hostname)
#   --update-only       Only update flake.lock, without rebuilding the system
#   --rebuild-only      Only rebuild the system, without updating flake.lock
#   --help, -h          Show help and exit

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

# ---------------------------------------------------------------------------
# Ensure running as root
# ---------------------------------------------------------------------------

if [[ $EUID -ne 0 ]]; then
  info "This script must run as root. Re-executing with sudo..."
  exec sudo -E bash "${BASH_SOURCE[0]}" "$@"
fi

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

OPT_HOST=""
OPT_UPDATE_ONLY=false
OPT_REBUILD_ONLY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)         OPT_HOST="$2"; shift 2 ;;
    --update-only)  OPT_UPDATE_ONLY=true; shift ;;
    --rebuild-only) OPT_REBUILD_ONLY=true; shift ;;
    --help|-h)
      cat <<'EOF'
Usage:
  bash scripts/update.sh [--host <hostname>] [--update-only] [--rebuild-only]
                         [--help]

Options:
  --host <hostname>   NixOS host name (default: current hostname)
  --update-only       Only update flake.lock, without rebuilding the system
  --rebuild-only      Only rebuild the system, without updating flake.lock
  --help, -h          Show this help and exit

Examples:
  # Full update (flake update + rebuild):
  sudo bash scripts/update.sh

  # Only update flake inputs:
  sudo bash scripts/update.sh --update-only

  # Only rebuild (without updating inputs):
  sudo bash scripts/update.sh --rebuild-only

  # Update a specific host:
  sudo bash scripts/update.sh --host barbudus
EOF
      exit 0 ;;
    *) die "Unknown option: $1. Use --help to see the available options." ;;
  esac
done

if [[ "$OPT_UPDATE_ONLY" == "true" && "$OPT_REBUILD_ONLY" == "true" ]]; then
  die "--update-only and --rebuild-only are mutually exclusive."
fi

# ---------------------------------------------------------------------------
# Detect host
# ---------------------------------------------------------------------------

if [[ -z "$OPT_HOST" ]]; then
  OPT_HOST="$(hostname)"
fi
HOST="$OPT_HOST"

# Detect the configuration directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Check whether the NixOS configuration is available
NIXOS_CONFIG="/etc/nixos"
if [[ ! -f "$NIXOS_CONFIG/flake.nix" ]]; then
  # Try using the repository directory
  if [[ -f "$CONFIG_DIR/flake.nix" ]]; then
    NIXOS_CONFIG="$CONFIG_DIR"
    warn "Using configuration from $NIXOS_CONFIG (not /etc/nixos)"
  else
    die "NixOS configuration not found in /etc/nixos or in $CONFIG_DIR"
  fi
fi

echo
echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║             NixOS Update — ${HOST}${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
echo
info "Configuration: $NIXOS_CONFIG"
info "Host: $HOST"
echo

# ---------------------------------------------------------------------------
# Step 1: Update flake inputs
# ---------------------------------------------------------------------------

if [[ "$OPT_REBUILD_ONLY" != "true" ]]; then
  info "==> Step 1: Updating flake inputs..."
  nix flake update "$NIXOS_CONFIG"
  success "Flake inputs updated."
  echo
fi

# ---------------------------------------------------------------------------
# Step 2: Rebuild the system
# ---------------------------------------------------------------------------

if [[ "$OPT_UPDATE_ONLY" != "true" ]]; then
  info "==> Step 2: Rebuilding the system..."
  nixos-rebuild switch --flake "${NIXOS_CONFIG}#${HOST}"
  success "System rebuilt successfully!"
  echo
fi

echo -e "${GREEN}${BOLD}Update complete!${RESET}"
