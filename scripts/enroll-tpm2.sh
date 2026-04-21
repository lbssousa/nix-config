#!/usr/bin/env bash
# enroll-tpm2.sh — Configurar desbloqueio automático do LUKS via chip TPM2
#
# Usa systemd-cryptenroll para registrar o TPM2 como fator de autenticação
# do volume LUKS, permitindo que o sistema desbloqueie automaticamente o
# disco na inicialização — desde que as medições de integridade (PCRs)
# correspondam ao estado esperado.
#
# ⚠️  Execute este script APÓS a primeira inicialização bem-sucedida do sistema.
#
# Uso:
#   bash scripts/enroll-tpm2.sh [--device <partição>] [--pcrs <pcrs>]
#                               [--wipe] [--help]
#
# Opções:
#   --device <partição>  Partição LUKS (padrão: /dev/disk/by-partlabel/luks)
#   --pcrs <pcrs>        PCRs a monitorar (padrão: 0+2+7)
#                        0 = Firmware UEFI
#                        2 = Código de opção UEFI (drivers ROM)
#                        7 = Estado do Secure Boot
#   --wipe               Remove o slot TPM2 existente antes de reinscrever
#                        (útil para reinscrever após mudanças no firmware)
#   --help, -h           Exibe ajuda e sai

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

OPT_DEVICE="/dev/disk/by-partlabel/luks"
OPT_PCRS="0+2+7"
OPT_WIPE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --device) OPT_DEVICE="$2"; shift 2 ;;
    --pcrs)   OPT_PCRS="$2";   shift 2 ;;
    --wipe)   OPT_WIPE=true;   shift ;;
    --help|-h)
      cat <<'EOF'
Uso:
  bash scripts/enroll-tpm2.sh [--device <partição>] [--pcrs <pcrs>]
                              [--wipe] [--help]

Opções:
  --device <partição>  Partição LUKS (padrão: /dev/disk/by-partlabel/luks)
  --pcrs <pcrs>        PCRs a monitorar, separados por + (padrão: 0+2+7)
                       0 = Firmware UEFI (integridade do firmware)
                       2 = Código de opção UEFI (drivers ROM)
                       7 = Estado do Secure Boot
  --wipe               Remove o slot TPM2 existente antes de reinscrever.
                       Use após atualizações de firmware ou mudanças no
                       Secure Boot que tornem o slot atual inválido.

Exemplos:
  # Inscrição padrão (PCRs 0+2+7, recomendado com Secure Boot):
  sudo bash scripts/enroll-tpm2.sh

  # Sem Secure Boot (apenas firmware e código de opção):
  sudo bash scripts/enroll-tpm2.sh --pcrs 0+2

  # Reinscrever após atualização de firmware:
  sudo bash scripts/enroll-tpm2.sh --wipe

  # Partição LUKS alternativa:
  sudo bash scripts/enroll-tpm2.sh --device /dev/nvme0n1p2

Para revogar o acesso TPM2 (ex: antes de vender o hardware):
  sudo systemd-cryptenroll --wipe-slot=tpm2 /dev/disk/by-partlabel/luks
EOF
      exit 0 ;;
    *) die "Opção desconhecida: $1. Use --help para ver as opções disponíveis." ;;
  esac
done

DEVICE="$OPT_DEVICE"
PCRS="$OPT_PCRS"

echo
echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║        Configuração de Desbloqueio LUKS via TPM2             ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
echo

# ---------------------------------------------------------------------------
# Verificações
# ---------------------------------------------------------------------------

info "==> Verificando pré-requisitos..."

# Verificar se o dispositivo LUKS existe
if [[ ! -b "$DEVICE" ]]; then
  die "Dispositivo LUKS não encontrado: $DEVICE
  Verifique com: ls -la /dev/disk/by-partlabel/
  Ou especifique o caminho correto com --device <partição>"
fi
success "Dispositivo LUKS encontrado: $DEVICE"

# Verificar se o TPM2 está disponível
if ! command -v systemd-cryptenroll >/dev/null 2>&1; then
  die "systemd-cryptenroll não encontrado. Verifique se o systemd está instalado."
fi

TPM_DEVICES=$(ls /dev/tpm* 2>/dev/null || true)
if [[ -z "$TPM_DEVICES" ]]; then
  die "Nenhum dispositivo TPM encontrado em /dev/tpm*.
  Verifique se o TPM2 está habilitado na UEFI/BIOS do sistema."
fi
success "TPM2 detectado: $TPM_DEVICES"

# Verificar se o cryptsetup está disponível
if ! command -v cryptsetup >/dev/null 2>&1; then
  die "cryptsetup não encontrado."
fi

# Verificar se o dispositivo é um volume LUKS
if ! cryptsetup isLuks "$DEVICE" 2>/dev/null; then
  die "$DEVICE não é um volume LUKS válido."
fi
success "Volume LUKS válido: $DEVICE"

echo
info "Dispositivo: $DEVICE"
info "PCRs:        $PCRS"
echo

# ---------------------------------------------------------------------------
# Remover slot TPM2 existente (se --wipe)
# ---------------------------------------------------------------------------

if [[ "$OPT_WIPE" == "true" ]]; then
  info "==> Removendo slot TPM2 existente..."
  if systemd-cryptenroll --wipe-slot=tpm2 "$DEVICE"; then
    success "Slot TPM2 removido."
  else
    warn "Nenhum slot TPM2 encontrado para remover (ou remoção falhou)."
  fi
  echo
fi

# ---------------------------------------------------------------------------
# Inscrever o TPM2
# ---------------------------------------------------------------------------

info "==> Inscrevendo o TPM2 no volume LUKS..."
info "    (Você pode ser solicitado a digitar a senha LUKS para autorizar)"
echo

systemd-cryptenroll \
  --tpm2-device=auto \
  --tpm2-pcrs="$PCRS" \
  "$DEVICE"

echo
success "TPM2 inscrito com sucesso!"
echo
info "O sistema desbloqueará automaticamente o disco na próxima inicialização,"
info "desde que as medições dos PCRs [$PCRS] correspondam ao estado atual."
echo
warn "IMPORTANTE: Reinscreva o TPM2 após:"
warn "  • Atualizações de firmware (UEFI/BIOS)"
warn "  • Mudanças nas configurações do Secure Boot"
warn "  • Troca de hardware (placa-mãe, chip TPM)"
echo
info "Para revogar o acesso TPM2:"
echo "  sudo systemd-cryptenroll --wipe-slot=tpm2 $DEVICE"
