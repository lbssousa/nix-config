#!/usr/bin/env bash
# update-gregorio-pkgs.sh — Verificar novas versões e hashes dos pacotes Gregorio
#
# Consulta o repositório gregorio-lsp no GitHub e exibe as informações
# necessárias para atualizar pkgs/gregorio-lsp/package.nix.
# Desde a versão 0.4.0, o gregolint é um binário do mesmo crate.
#
# Uso:
#   bash scripts/update-gregorio-pkgs.sh [--apply] [--help]
#
# Opções:
#   --apply   Aplica as atualizações diretamente em pkgs/gregorio-lsp/package.nix
#   --help    Exibe esta ajuda e sai

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
    command -v "$cmd" &>/dev/null || die "Dependência não encontrada: $cmd"
  done
}

# ---------------------------------------------------------------------------
# Constantes
# ---------------------------------------------------------------------------

OWNER="AISCGre-BR"
REPO="gregorio-lsp"
PACKAGE_NIX="$(cd "$(dirname "$0")/.." && pwd)/pkgs/gregorio-lsp/package.nix"

# ---------------------------------------------------------------------------
# Argumentos
# ---------------------------------------------------------------------------

APPLY=false

for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=true ;;
    --help|-h)
      sed -n '2,15p' "$0" | sed 's/^# *//'
      exit 0
      ;;
    *) die "Argumento desconhecido: $arg" ;;
  esac
done

# ---------------------------------------------------------------------------
# Verificar dependências
# ---------------------------------------------------------------------------

require gh nix jq

# ---------------------------------------------------------------------------
# Buscar última versão e commit
# ---------------------------------------------------------------------------

info "Consultando releases de ${OWNER}/${REPO}..."

# /latest retorna 404 para pré-releases; usar a listagem completa como fallback
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
  || die "Não foi possível obter o último release de ${OWNER}/${REPO}"

NEW_VERSION="${LATEST_TAG#v}"

info "Última versão disponível: ${BOLD}${NEW_VERSION}${RESET}"

# Obter o commit SHA apontado pela tag
NEW_REV=$(gh api "repos/${OWNER}/${REPO}/git/refs/tags/${LATEST_TAG}" \
  --jq '.object.sha' 2>/dev/null) \
  || die "Não foi possível obter o SHA da tag ${LATEST_TAG}"

# Se a tag for anotada, resolver para o commit real
OBJECT_TYPE=$(gh api "repos/${OWNER}/${REPO}/git/refs/tags/${LATEST_TAG}" \
  --jq '.object.type' 2>/dev/null)
if [[ "$OBJECT_TYPE" == "tag" ]]; then
  NEW_REV=$(gh api "repos/${OWNER}/${REPO}/git/tags/${NEW_REV}" \
    --jq '.object.sha' 2>/dev/null) \
    || die "Não foi possível resolver o commit da tag anotada ${LATEST_TAG}"
fi

info "Commit da tag ${LATEST_TAG}: ${NEW_REV}"

# ---------------------------------------------------------------------------
# Verificar versão atual no package.nix
# ---------------------------------------------------------------------------

[[ -f "$PACKAGE_NIX" ]] || die "Arquivo não encontrado: $PACKAGE_NIX"

CURRENT_VERSION=$(grep -oP 'version = "\K[^"]+' "$PACKAGE_NIX" | head -1)
CURRENT_REV=$(grep -oP 'rev = "\K[^"]+' "$PACKAGE_NIX" | head -1)

info "Versão atual no package.nix: ${BOLD}${CURRENT_VERSION}${RESET} (rev: ${CURRENT_REV:0:12}...)"

if [[ "$CURRENT_VERSION" == "$NEW_VERSION" && "$CURRENT_REV" == "$NEW_REV" ]]; then
  success "O pacote já está atualizado para a versão ${NEW_VERSION}."
  exit 0
fi

echo ""
echo -e "${BOLD}Atualização disponível:${RESET}"
echo -e "  Versão: ${CURRENT_VERSION} → ${BOLD}${NEW_VERSION}${RESET}"
echo -e "  Rev:    ${CURRENT_REV:0:12}... → ${BOLD}${NEW_REV:0:12}...${RESET}"
echo ""

# ---------------------------------------------------------------------------
# Calcular hash da fonte
# ---------------------------------------------------------------------------

info "Calculando hash da fonte (fetchFromGitHub)..."
PREFETCH_JSON=$(nix run nixpkgs#nix-prefetch-github -- \
  --rev "$NEW_REV" "$OWNER" "$REPO" 2>/dev/null) \
  || die "Falha ao calcular o hash da fonte"

NEW_HASH=$(echo "$PREFETCH_JSON" | jq -r '.hash')
info "Novo hash da fonte: ${NEW_HASH}"

# ---------------------------------------------------------------------------
# Calcular cargoHash usando hash falso e capturando o correto
# ---------------------------------------------------------------------------

info "Calculando cargoHash (pode demorar alguns minutos)..."

TMPFILE=$(mktemp /tmp/gregorio-lsp-pkg.XXXXXX.nix)
trap 'rm -f "$TMPFILE"' EXIT

# Copiar package.nix com versão/rev/hash atualizados e cargoHash falso
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
  # Pode já ter sido cacheado: a build passou com o hash falso
  if echo "$CARGO_HASH_OUTPUT" | grep -q "/nix/store/"; then
    warn "O cargoHash não mudou em relação ao cache. Verificando hash atual..."
    NEW_CARGO_HASH=$(grep -oP 'cargoHash = "\K[^"]+' "$PACKAGE_NIX" | head -1)
  else
    error "Não foi possível determinar o novo cargoHash. Saída do build:"
    echo "$CARGO_HASH_OUTPUT" | tail -20
    die "Verifique manualmente."
  fi
fi

info "Novo cargoHash: ${NEW_CARGO_HASH}"

# ---------------------------------------------------------------------------
# Exibir resumo
# ---------------------------------------------------------------------------

echo ""
echo -e "${BOLD}Valores para atualizar em pkgs/gregorio-lsp/package.nix:${RESET}"
echo ""
printf "  %-14s %s\n" "version"    "\"${NEW_VERSION}\""
printf "  %-14s %s\n" "rev"        "\"${NEW_REV}\""
printf "  %-14s %s\n" "hash"       "\"${NEW_HASH}\""
printf "  %-14s %s\n" "cargoHash"  "\"${NEW_CARGO_HASH}\""
echo ""

# ---------------------------------------------------------------------------
# Aplicar (opcional)
# ---------------------------------------------------------------------------

if $APPLY; then
  info "Aplicando atualizações em ${PACKAGE_NIX}..."

  CURRENT_HASH=$(grep -oP 'hash = "\K[^"]+' "$PACKAGE_NIX" | head -1)
  CURRENT_CARGO_HASH=$(grep -oP 'cargoHash = "\K[^"]+' "$PACKAGE_NIX" | head -1)

  sed -i \
    -e "s|version = \"${CURRENT_VERSION}\"|version = \"${NEW_VERSION}\"|" \
    -e "s|rev = \"${CURRENT_REV}\"|rev = \"${NEW_REV}\"|" \
    -e "s|hash = \"${CURRENT_HASH}\"|hash = \"${NEW_HASH}\"|" \
    -e "s|cargoHash = \"${CURRENT_CARGO_HASH}\"|cargoHash = \"${NEW_CARGO_HASH}\"|" \
    "$PACKAGE_NIX"

  success "pkgs/gregorio-lsp/package.nix atualizado para a versão ${NEW_VERSION}."
  echo ""
  info "Verifique o resultado com:  nix-build -E 'let p = import <nixpkgs> {}; in p.callPackage ./pkgs/gregorio-lsp/package.nix {}'"
else
  info "Use ${BOLD}--apply${RESET} para aplicar as alterações automaticamente."
fi
