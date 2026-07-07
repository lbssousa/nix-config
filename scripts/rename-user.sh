#!/usr/bin/env bash
# rename-user.sh — Renames a NixOS user in this configuration repository
#
# Automates:
#   1. Renames the system account (usermod / groupmod)
#   2. Moves the home directory (/home/<old> → /home/<new>)
#   3. Renames and updates the Nix files (users/<old>.nix,
#      dendritic/data/users.nix, home/users/<old>/)
#   4. Updates files persisted in /persist (password flags, u2f-mappings)
#   5. Stages all changes in git
#   6. Offers to run 'nixos-rebuild switch' at the end (Home Manager is a
#      NixOS module — this one command applies both)
#
# Usage:
#   sudo bash scripts/rename-user.sh <old-name> <new-name>
#
# Preconditions:
#   - Run as root
#   - The old user must not have an active session
#   - The new name must not already be in use on the system
#   - Run from the NixOS repository directory (/etc/nixos)
#
# After the script:
#   - If the user has sops keys (secrets/*.yaml), rename them manually:
#       sops secrets/<file>.yaml
#   - If home/users/<new>/*.nix has hardcoded references to the old login
#     (e.g. inputs.nix-secrets.<old>.*, sops secret keys "<old>/..."), review
#     and update them by hand — this script only renames the directory.
#   - Run 'nixos-rebuild switch' again if you skipped step 6 below.

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Output helpers
# ─────────────────────────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${BLUE}==>${NC} ${BOLD}$*${NC}"; }
success() { echo -e "${GREEN}  ✓${NC} $*"; }
warn()    { echo -e "${YELLOW}  ⚠${NC}  $*"; }
error()   { echo -e "${RED}  ✗${NC} $*" >&2; }
die()     { error "$*"; exit 1; }

confirm() {
    local msg="$1"
    local reply
    echo -en "${YELLOW}  ?${NC} ${msg} [y/N] "
    read -r reply
    [[ "${reply,,}" == "y" || "${reply,,}" == "yes" ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# Arguments and initial checks
# ─────────────────────────────────────────────────────────────────────────────

[[ $EUID -eq 0 ]] || die "Run as root: sudo bash $0 ${*:-<old> <new>}"

if [[ $# -ne 2 ]]; then
    echo "Usage: sudo bash $0 <old-name> <new-name>"
    echo
    echo "Example: sudo bash $0 laercio abutre"
    exit 1
fi

OLD_NAME="$1"
NEW_NAME="$2"

[[ "$OLD_NAME" =~ ^[a-z][a-z0-9_-]*$ ]] || die "Invalid name: '$OLD_NAME'"
[[ "$NEW_NAME" =~ ^[a-z][a-z0-9_-]*$ ]] || die "Invalid name: '$NEW_NAME'"
[[ "$OLD_NAME" != "$NEW_NAME" ]]          || die "The names are identical."

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# Verify we're in the correct NixOS repository
[[ -f "$REPO_ROOT/flake.nix" ]] || die "flake.nix not found in '$REPO_ROOT'. Run this from the NixOS repository."

# ─────────────────────────────────────────────────────────────────────────────
# Check preconditions
# ─────────────────────────────────────────────────────────────────────────────

id "$OLD_NAME" &>/dev/null     || die "User '$OLD_NAME' does not exist on the system."
! id "$NEW_NAME" &>/dev/null   || die "User '$NEW_NAME' already exists on the system."

# Warn about an active session
if who | awk '{print $1}' | grep -qx "$OLD_NAME"; then
    warn "User '$OLD_NAME' has an active session."
    warn "Renaming a user with an open session may cause unexpected behavior."
    echo
    confirm "Continue anyway?" || exit 1
    echo
fi

# ─────────────────────────────────────────────────────────────────────────────
# Operation summary
# ─────────────────────────────────────────────────────────────────────────────

echo
echo -e "  ${BOLD}Rename user:${NC} ${RED}${OLD_NAME}${NC} → ${GREEN}${NEW_NAME}${NC}"
echo
echo    "  System"
echo    "    • usermod -l / groupmod -n"
[[ -d "/home/$OLD_NAME" ]] && echo "    • /home/${OLD_NAME} → /home/${NEW_NAME}"
echo    "  Nix configuration"
[[ -f "$REPO_ROOT/users/${OLD_NAME}.nix" ]] && \
    echo "    • users/${OLD_NAME}.nix → users/${NEW_NAME}.nix"
echo    "    • dendritic/data/users.nix"
[[ -d "$REPO_ROOT/home/users/${OLD_NAME}" ]] && \
    echo "    • home/users/${OLD_NAME}/ → home/users/${NEW_NAME}/"
echo    "  /persist"
[[ -f "/persist/.password-change-required-${OLD_NAME}" ]] && \
    echo "    • .password-change-required-${OLD_NAME} → .password-change-required-${NEW_NAME}"
[[ -f "/persist/etc/u2f-mappings" ]] && grep -q "^${OLD_NAME}:" /persist/etc/u2f-mappings && \
    echo "    • u2f-mappings: entry '${OLD_NAME}' updated"
echo

confirm "Confirm the rename?" || exit 1
echo

# ─────────────────────────────────────────────────────────────────────────────
# Step 1 — Rename the system account
# ─────────────────────────────────────────────────────────────────────────────

info "Renaming the system account..."

usermod -l "$NEW_NAME" "$OLD_NAME"
success "Login renamed: ${OLD_NAME} → ${NEW_NAME}"

if getent group "$OLD_NAME" &>/dev/null; then
    groupmod -n "$NEW_NAME" "$OLD_NAME"
    success "Primary group renamed: ${OLD_NAME} → ${NEW_NAME}"
fi

# Move the home directory
OLD_HOME="/home/$OLD_NAME"
NEW_HOME="/home/$NEW_NAME"

if [[ -d "$OLD_HOME" ]]; then
    usermod -d "$NEW_HOME" -m "$NEW_NAME"
    success "Home moved: ${OLD_HOME} → ${NEW_HOME}"
else
    usermod -d "$NEW_HOME" "$NEW_NAME"
    warn "Directory ${OLD_HOME} not found; home field updated without moving files."
fi

# ─────────────────────────────────────────────────────────────────────────────
# Step 2 — Update files under /persist
# ─────────────────────────────────────────────────────────────────────────────

info "Updating persisted files..."

OLD_FLAG="/persist/.password-change-required-${OLD_NAME}"
NEW_FLAG="/persist/.password-change-required-${NEW_NAME}"
if [[ -f "$OLD_FLAG" ]]; then
    mv "$OLD_FLAG" "$NEW_FLAG"
    success "Password flag: ${OLD_FLAG##*/} → ${NEW_FLAG##*/}"
fi

U2F_FILE="/persist/etc/u2f-mappings"
if [[ -f "$U2F_FILE" ]] && grep -q "^${OLD_NAME}:" "$U2F_FILE"; then
    sed -i "s/^${OLD_NAME}:/${NEW_NAME}:/" "$U2F_FILE"
    success "u2f-mappings: entry '${OLD_NAME}' → '${NEW_NAME}'"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Step 3 — Rename and update Nix files
# ─────────────────────────────────────────────────────────────────────────────

info "Updating Nix configuration..."

# users/<old>.nix → users/<new>.nix
# NOTE: this only replaces quoted string literals ("old" -> "new"), e.g.
# username = "old"; or [ "old" ]. Unquoted attribute paths that embed the
# login (like users.users.old.packages) are NOT rewritten — check the file
# by hand afterwards if it has custom blocks beyond the mkUser.nix import.
USER_FILE_OLD="$REPO_ROOT/users/${OLD_NAME}.nix"
USER_FILE_NEW="$REPO_ROOT/users/${NEW_NAME}.nix"
if [[ -f "$USER_FILE_OLD" ]]; then
    git mv "$USER_FILE_OLD" "$USER_FILE_NEW"
    sed -i "s/\"${OLD_NAME}\"/\"${NEW_NAME}\"/g" "$USER_FILE_NEW"
    git add "$USER_FILE_NEW"
    success "users/${OLD_NAME}.nix → users/${NEW_NAME}.nix"
else
    warn "File users/${OLD_NAME}.nix not found; skipping."
fi

# dendritic/data/users.nix — the single inventory (config.dendritic.users)
# that both hosts/nixos-configurations.nix (system account) and
# dendritic/flake/home-nixos-module.nix (Home Manager) read from. There's no
# separate per-user "home configuration" file to update.
DENDRITIC_USERS_FILE="$REPO_ROOT/dendritic/data/users.nix"
if grep -q "\"${OLD_NAME}\"" "$DENDRITIC_USERS_FILE"; then
    sed -i "s/\"${OLD_NAME}\"/\"${NEW_NAME}\"/" "$DENDRITIC_USERS_FILE"
    git add "$DENDRITIC_USERS_FILE"
    success "dendritic/data/users.nix updated"
else
    warn "'${OLD_NAME}' not found in dendritic/data/users.nix; skipping."
fi

# home/users/<old>/ → home/users/<new>/ (optional per-user Home Manager
# overrides, imported by mkUserHome in dendritic/flake/home-nixos-module.nix
# when the directory exists). Only the directory is renamed — file contents
# may still reference the old login (see the note printed at the end).
HOME_USER_DIR_OLD="$REPO_ROOT/home/users/${OLD_NAME}"
HOME_USER_DIR_NEW="$REPO_ROOT/home/users/${NEW_NAME}"
if [[ -d "$HOME_USER_DIR_OLD" ]]; then
    git mv "$HOME_USER_DIR_OLD" "$HOME_USER_DIR_NEW"
    git add "$HOME_USER_DIR_NEW"
    success "home/users/${OLD_NAME}/ → home/users/${NEW_NAME}/"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Step 4 — Check sops secrets
# ─────────────────────────────────────────────────────────────────────────────

SECRETS_DIR="$REPO_ROOT/secrets"
SOPS_FILES=()
while IFS= read -r -d '' f; do
    SOPS_FILES+=("$f")
done < <(find "$SECRETS_DIR" -name '*.yaml' -print0 2>/dev/null)

if [[ ${#SOPS_FILES[@]} -gt 0 ]]; then
    SOPS_MATCHES=()
    for f in "${SOPS_FILES[@]}"; do
        # Decrypt only to inspect keys; fails silently without an age key
        if sops --decrypt "$f" 2>/dev/null | grep -q "${OLD_NAME}"; then
            SOPS_MATCHES+=("${f#"$REPO_ROOT/"}")
        fi
    done
    if [[ ${#SOPS_MATCHES[@]} -gt 0 ]]; then
        echo
        warn "The following sops files contain keys with '${OLD_NAME}':"
        for f in "${SOPS_MATCHES[@]}"; do
            warn "  • ${f}"
        done
        warn "Rename the keys manually after the script:"
        warn "  sops secrets/<file>.yaml"
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# Done
# ─────────────────────────────────────────────────────────────────────────────

echo
success "Rename complete: ${OLD_NAME} → ${NEW_NAME}"
echo

# ─────────────────────────────────────────────────────────────────────────────
# Step 5 — nixos-rebuild switch (optional)
# ─────────────────────────────────────────────────────────────────────────────

HOST="$(hostname)"
if confirm "Run 'nixos-rebuild switch --flake /etc/nixos#${HOST}' now?"; then
    echo
    info "Running nixos-rebuild switch..."
    nixos-rebuild switch --flake "/etc/nixos#${HOST}"
    echo
    success "System updated."
    echo
    warn "Home Manager is a NixOS module, so ${NEW_NAME}'s environment was"
    warn "already regenerated by the switch above — no separate command needed."
else
    echo
    warn "Next step:"
    warn "  nixos-rebuild switch --flake /etc/nixos#${HOST}"
    warn "(Home Manager is a NixOS module — this one command applies both.)"
fi

echo
