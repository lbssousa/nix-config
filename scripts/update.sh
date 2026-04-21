#!/usr/bin/env bash
# update.sh — Atualizar o sistema NixOS
#
# Atualiza os inputs do flake e reconstrói o sistema com nixos-rebuild switch.
#
# Uso:
#   bash scripts/update.sh [--host <hostname>] [--update-only] [--rebuild-only]
#                          [--help]
#
# Opções:
#   --host <hostname>   Nome do host NixOS (padrão: hostname atual)
#   --update-only       Apenas atualiza flake.lock, sem reconstruir o sistema
#   --rebuild-only      Apenas reconstrói o sistema, sem atualizar o flake.lock
#   --help, -h          Exibe ajuda e sai

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
# Garantir execução como root
# ---------------------------------------------------------------------------

if [[ $EUID -ne 0 ]]; then
  info "Este script deve ser executado como root. Reexecutando com sudo..."
  exec sudo -E bash "${BASH_SOURCE[0]}" "$@"
fi

# ---------------------------------------------------------------------------
# Argumento parsing
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
Uso:
  bash scripts/update.sh [--host <hostname>] [--update-only] [--rebuild-only]
                         [--help]

Opções:
  --host <hostname>   Nome do host NixOS (padrão: hostname atual)
  --update-only       Apenas atualiza flake.lock, sem reconstruir o sistema
  --rebuild-only      Apenas reconstrói o sistema, sem atualizar o flake.lock
  --help, -h          Exibe esta ajuda e sai

Exemplos:
  # Atualização completa (flake update + rebuild):
  sudo bash scripts/update.sh

  # Apenas atualizar flake inputs:
  sudo bash scripts/update.sh --update-only

  # Apenas rebuild (sem atualizar inputs):
  sudo bash scripts/update.sh --rebuild-only

  # Atualizar host específico:
  sudo bash scripts/update.sh --host barbudus
EOF
      exit 0 ;;
    *) die "Opção desconhecida: $1. Use --help para ver as opções disponíveis." ;;
  esac
done

if [[ "$OPT_UPDATE_ONLY" == "true" && "$OPT_REBUILD_ONLY" == "true" ]]; then
  die "--update-only e --rebuild-only são mutuamente exclusivos."
fi

# ---------------------------------------------------------------------------
# Detectar host
# ---------------------------------------------------------------------------

if [[ -z "$OPT_HOST" ]]; then
  OPT_HOST="$(hostname)"
fi
HOST="$OPT_HOST"

# Detectar o diretório da configuração
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Verificar se a configuração do NixOS está disponível
NIXOS_CONFIG="/etc/nixos"
if [[ ! -f "$NIXOS_CONFIG/flake.nix" ]]; then
  # Tentar usar o diretório do repositório
  if [[ -f "$CONFIG_DIR/flake.nix" ]]; then
    NIXOS_CONFIG="$CONFIG_DIR"
    warn "Usando configuração de $NIXOS_CONFIG (não /etc/nixos)"
  else
    die "Configuração do NixOS não encontrada em /etc/nixos nem em $CONFIG_DIR"
  fi
fi

echo
echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║             Atualização do NixOS — ${HOST}${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
echo
info "Configuração: $NIXOS_CONFIG"
info "Host: $HOST"
echo

# ---------------------------------------------------------------------------
# Passo 1: Atualizar flake inputs
# ---------------------------------------------------------------------------

if [[ "$OPT_REBUILD_ONLY" != "true" ]]; then
  info "==> Passo 1: Atualizando flake inputs..."
  nix flake update "$NIXOS_CONFIG"
  success "Flake inputs atualizados."
  echo
fi

# ---------------------------------------------------------------------------
# Passo 2: Reconstruir o sistema
# ---------------------------------------------------------------------------

if [[ "$OPT_UPDATE_ONLY" != "true" ]]; then
  info "==> Passo 2: Reconstruindo o sistema..."
  nixos-rebuild switch --flake "${NIXOS_CONFIG}#${HOST}"
  success "Sistema reconstruído com sucesso!"
  echo
fi

echo -e "${GREEN}${BOLD}Atualização concluída!${RESET}"
