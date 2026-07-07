#!/usr/bin/env bash
# update-gregorio-pkgs.sh — Check for new versions and hashes of the Gregorio packages
#
# Queries the gregorio-lsp repository on GitHub and prints the information
# needed to update pkgs/gregorio-lsp/package.nix.
# Since version 0.4.0, gregolint is a binary from the same crate.
#
# Usage:
#   bash scripts/update-gregorio-pkgs.sh [--apply] [--help]
#
# Options:
#   --apply   Applies the updates directly to pkgs/gregorio-lsp/package.nix
#   --help    Shows this help and exits

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

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERRO]${RESET}  $*" >&2; }
die()     { error "$*"; exit 1; }

require() {
  for cmd in "$@"; do
    command -v "$cmd" &>/dev/null || die "Dependency not found: $cmd"
  done
}

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

OWNER="AISCGre-BR"
REPO="gregorio-lsp"
PACKAGE_NIX="$(cd "$(dirname "$0")/.." && pwd)/pkgs/gregorio-lsp/package.nix"

# ---------------------------------------------------------------------------
# Arguments
# ---------------------------------------------------------------------------

APPLY=false

for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=true ;;
    --help|-h)
      sed -n '2,15p' "$0" | sed 's/^# *//'
      exit 0
      ;;
    *) die "Unknown argument: $arg" ;;
  esac
done

# ---------------------------------------------------------------------------
# Check dependencies
# ---------------------------------------------------------------------------

require gh nix jq

# ---------------------------------------------------------------------------
# Fetch the latest version and commit
# ---------------------------------------------------------------------------

info "Querying releases for ${OWNER}/${REPO}..."

# /latest returns 404 for pre-releases; use the full listing as a fallback
LATEST_TAG=""
if gh api "repos/${OWNER}/${REPO}/releases/latest" --jq '.tag_name' \
     >/tmp/_gh_latest.txt 2>/dev/null; then
  LATEST_TAG=$(cat /tmp/_gh_latest.txt | tr -d '\n')
fi
if [[ -z "$LATEST_TAG" || "$LATEST_TAG" == "null" ]]; then
  LATEST_TAG=$(gh api "repos/${OWNER}/${REPO}/releases" --jq '.[0].tag_name' 2>/dev/null \
    | tr -d '\n') || true
fi
rm -f /tmp/_gh_latest.txt
[[ -n "$LATEST_TAG" && "$LATEST_TAG" != "null" ]] \
  || die "Could not fetch the latest release for ${OWNER}/${REPO}"

NEW_VERSION="${LATEST_TAG#v}"

info "Latest version available: ${BOLD}${NEW_VERSION}${RESET}"

# Get the commit SHA pointed to by the tag
NEW_REV=$(gh api "repos/${OWNER}/${REPO}/git/refs/tags/${LATEST_TAG}" \
  --jq '.object.sha' 2>/dev/null) \
  || die "Could not get the SHA for tag ${LATEST_TAG}"

# If the tag is annotated, resolve it to the actual commit
OBJECT_TYPE=$(gh api "repos/${OWNER}/${REPO}/git/refs/tags/${LATEST_TAG}" \
  --jq '.object.type' 2>/dev/null)
if [[ "$OBJECT_TYPE" == "tag" ]]; then
  NEW_REV=$(gh api "repos/${OWNER}/${REPO}/git/tags/${NEW_REV}" \
    --jq '.object.sha' 2>/dev/null) \
    || die "Could not resolve the commit for annotated tag ${LATEST_TAG}"
fi

info "Commit for tag ${LATEST_TAG}: ${NEW_REV}"

# ---------------------------------------------------------------------------
# Check the current version in package.nix
# ---------------------------------------------------------------------------

[[ -f "$PACKAGE_NIX" ]] || die "File not found: $PACKAGE_NIX"

CURRENT_VERSION=$(grep -oP 'version = "\K[^"]+' "$PACKAGE_NIX" | head -1)
CURRENT_REV=$(grep -oP 'rev = "\K[^"]+' "$PACKAGE_NIX" | head -1)

info "Current version in package.nix: ${BOLD}${CURRENT_VERSION}${RESET} (rev: ${CURRENT_REV:0:12}...)"

if [[ "$CURRENT_VERSION" == "$NEW_VERSION" && "$CURRENT_REV" == "$NEW_REV" ]]; then
  success "The package is already up to date at version ${NEW_VERSION}."
  exit 0
fi

echo ""
echo -e "${BOLD}Update available:${RESET}"
echo -e "  Version: ${CURRENT_VERSION} → ${BOLD}${NEW_VERSION}${RESET}"
echo -e "  Rev:     ${CURRENT_REV:0:12}... → ${BOLD}${NEW_REV:0:12}...${RESET}"
echo ""

# ---------------------------------------------------------------------------
# Compute the source hash
# ---------------------------------------------------------------------------

info "Computing the source hash (fetchFromGitHub)..."
PREFETCH_JSON=$(nix run nixpkgs#nix-prefetch-github -- \
  --rev "$NEW_REV" "$OWNER" "$REPO" 2>/dev/null) \
  || die "Failed to compute the source hash"

NEW_HASH=$(echo "$PREFETCH_JSON" | jq -r '.hash')
info "New source hash: ${NEW_HASH}"

# ---------------------------------------------------------------------------
# Compute cargoHash using a fake hash and capturing the correct one
# ---------------------------------------------------------------------------

info "Computing cargoHash (this can take a few minutes)..."

TMPFILE=$(mktemp /tmp/gregorio-lsp-pkg.XXXXXX.nix)
trap 'rm -f "$TMPFILE"' EXIT

# Copy package.nix with the updated version/rev/hash and a fake cargoHash
sed \
  -e "s|version = \"[^\"]*\"|version = \"${NEW_VERSION}\"|" \
  -e "s|rev = \"[^\"]*\"|rev = \"${NEW_REV}\"|" \
  -e "s|hash = \"[^\"]*\"|hash = \"${NEW_HASH}\"|" \
  -e 's|cargoHash = "[^"]*"|cargoHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="|' \
  "$PACKAGE_NIX" > "$TMPFILE"

CARGO_HASH_OUTPUT=$(nix-build -E "
  let pkgs = import <nixpkgs> {};
  in pkgs.callPackage ${TMPFILE} {}
" 2>&1 || true)

NEW_CARGO_HASH=$(echo "$CARGO_HASH_OUTPUT" | grep -oP 'got:\s+\Ksha256-\S+' | head -1)

if [[ -z "$NEW_CARGO_HASH" ]]; then
  # May already be cached: the build passed with the fake hash
  if echo "$CARGO_HASH_OUTPUT" | grep -q "/nix/store/"; then
    warn "cargoHash didn't change compared to the cache. Checking the current hash..."
    NEW_CARGO_HASH=$(grep -oP 'cargoHash = "\K[^"]+' "$PACKAGE_NIX" | head -1)
  else
    error "Could not determine the new cargoHash. Build output:"
    echo "$CARGO_HASH_OUTPUT" | tail -20
    die "Check it manually."
  fi
fi

info "New cargoHash: ${NEW_CARGO_HASH}"

# ---------------------------------------------------------------------------
# Show the summary
# ---------------------------------------------------------------------------

echo ""
echo -e "${BOLD}Values to update in pkgs/gregorio-lsp/package.nix:${RESET}"
echo ""
printf "  %-14s %s\n" "version"    "\"${NEW_VERSION}\""
printf "  %-14s %s\n" "rev"        "\"${NEW_REV}\""
printf "  %-14s %s\n" "hash"       "\"${NEW_HASH}\""
printf "  %-14s %s\n" "cargoHash"  "\"${NEW_CARGO_HASH}\""
echo ""

# ---------------------------------------------------------------------------
# Apply (optional)
# ---------------------------------------------------------------------------

if $APPLY; then
  info "Applying updates to ${PACKAGE_NIX}..."

  CURRENT_HASH=$(grep -oP 'hash = "\K[^"]+' "$PACKAGE_NIX" | head -1)
  CURRENT_CARGO_HASH=$(grep -oP 'cargoHash = "\K[^"]+' "$PACKAGE_NIX" | head -1)

  sed -i \
    -e "s|version = \"${CURRENT_VERSION}\"|version = \"${NEW_VERSION}\"|" \
    -e "s|rev = \"${CURRENT_REV}\"|rev = \"${NEW_REV}\"|" \
    -e "s|hash = \"${CURRENT_HASH}\"|hash = \"${NEW_HASH}\"|" \
    -e "s|cargoHash = \"${CURRENT_CARGO_HASH}\"|cargoHash = \"${NEW_CARGO_HASH}\"|" \
    "$PACKAGE_NIX"

  success "pkgs/gregorio-lsp/package.nix updated to version ${NEW_VERSION}."
  echo ""
  info "Check the result with:  nix-build -E 'let p = import <nixpkgs> {}; in p.callPackage ./pkgs/gregorio-lsp/package.nix {}'"
else
  info "Use ${BOLD}--apply${RESET} to apply the changes automatically."
fi
