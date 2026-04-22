#!/usr/bin/env bash
# setup-secureboot.sh — Configurar Secure Boot e assinar módulos do kernel (NVIDIA)
#
# Este script realiza as etapas pós-instalação necessárias para o Secure Boot
# funcionar com o lanzaboote:
#
#   1. Verificar o estado atual do Secure Boot e do sbctl
#   2. Registrar as chaves PKI no firmware UEFI (sbctl enroll-keys)
#   3. Assinar todas as entradas de boot pendentes (sbctl sign-all)
#   4. Verificar assinaturas (sbctl verify)
#
# ⚠️  Execute este script APÓS a primeira inicialização do sistema,
#     com o Secure Boot DESATIVADO no firmware (modo Setup Mode).
#     Após o script, reative o Secure Boot no firmware e reinicie.
#
# Uso:
#   bash scripts/setup-secureboot.sh [--enroll-only] [--sign-only]
#                                    [--verify-only] [--help]
#
# Opções:
#   --enroll-only   Apenas registra as chaves no firmware (sem sign/verify)
#   --sign-only     Apenas assina os binários pendentes (sem enroll/verify)
#   --verify-only   Apenas verifica as assinaturas (sem enroll/sign)
#   --help, -h      Exibe ajuda e sai

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

OPT_ENROLL_ONLY=false
OPT_SIGN_ONLY=false
OPT_VERIFY_ONLY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --enroll-only) OPT_ENROLL_ONLY=true; shift ;;
    --sign-only)   OPT_SIGN_ONLY=true;   shift ;;
    --verify-only) OPT_VERIFY_ONLY=true; shift ;;
    --help|-h)
      cat <<'EOF'
Uso:
  bash scripts/setup-secureboot.sh [--enroll-only] [--sign-only]
                                   [--verify-only] [--help]

Opções:
  --enroll-only   Apenas registra as chaves PKI no firmware UEFI
  --sign-only     Apenas assina os binários EFI pendentes
  --verify-only   Apenas verifica se todos os binários estão assinados
  --help, -h      Exibe esta ajuda e sai

Passos para configurar o Secure Boot:
  1. Inicialize o sistema com o Secure Boot DESATIVADO (Setup Mode na UEFI)
     (para ativar o Setup Mode: BIOS → Secure Boot → apagar chaves existentes)
  2. Execute este script para registrar chaves e assinar binários:
       sudo bash scripts/setup-secureboot.sh
  3. Reinicie e ative o Secure Boot na UEFI/BIOS
  4. Verifique se tudo está correto:
       sudo bash scripts/setup-secureboot.sh --verify-only

NOTA IMPORTANTE — Lanzaboote vs. MOK/shim:
  Esta configuração usa lanzaboote, que NÃO utiliza shim nem MOK.
  • Não haverá tela azul do MOKmanager durante o boot
  • Não será solicitada nenhuma senha de MOK
  • O lanzaboote assina os binários EFI (kernel + initrd) diretamente com
    chaves PKI próprias (PK/KEK/db) registradas no firmware UEFI
  • As chaves ficam em /persist/etc/secureboot (configurado via pkiBundle)
  • A cada nixos-rebuild switch, o lanzaboote reassina os binários

Notas:
  • As chaves PKI são criadas automaticamente durante a instalação (install.sh)
    e ficam em /persist/etc/secureboot (configurado via pkiBundle no lanzaboote)
  • O lanzaboote assina automaticamente o kernel e o initrd a cada nixos-rebuild
  • Os módulos NVIDIA ficam no initrd e são assinados junto com ele
  • Use sbctl verify para verificar quais binários não estão assinados
EOF
      exit 0 ;;
    *) die "Opção desconhecida: $1. Use --help para ver as opções disponíveis." ;;
  esac
done

# Verificar se apenas uma das flags exclusivas está ativa
_exclusive_count=0
[[ "$OPT_ENROLL_ONLY" == "true" ]] && (( _exclusive_count++ )) || true
[[ "$OPT_SIGN_ONLY"   == "true" ]] && (( _exclusive_count++ )) || true
[[ "$OPT_VERIFY_ONLY" == "true" ]] && (( _exclusive_count++ )) || true
if [[ $_exclusive_count -gt 1 ]]; then
  die "--enroll-only, --sign-only e --verify-only são mutuamente exclusivos."
fi

echo
echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║          Configuração do Secure Boot (Lanzaboote)            ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
echo

# ---------------------------------------------------------------------------
# Verificações
# ---------------------------------------------------------------------------

if ! command -v sbctl >/dev/null 2>&1; then
  die "sbctl não encontrado. Certifique-se de que o lanzaboote está configurado
  e que o sistema foi reconstruído com 'nixos-rebuild switch'."
fi

# ---------------------------------------------------------------------------
# Passo 1: Estado atual
# ---------------------------------------------------------------------------

info "==> Estado atual do Secure Boot:"
sbctl status || true
echo

# ---------------------------------------------------------------------------
# Passo 2: Registrar chaves PKI no firmware UEFI
# ---------------------------------------------------------------------------

if [[ "$OPT_SIGN_ONLY" != "true" && "$OPT_VERIFY_ONLY" != "true" ]]; then
  info "==> Registrando chaves PKI no firmware UEFI..."
  echo

  # Verificar se o firmware está em Setup Mode (pré-requisito para enroll-keys)
  # Com lanzaboote, NÃO existe senha de MOK nem tela do MOKmanager.
  # O lanzaboote usa suas próprias chaves PKI (PK/KEK/db) — não usa shim/MOK.
  _setup_mode=$(sbctl status 2>&1)
  if ! echo "$_setup_mode" | grep -qi "setup mode.*enabled\|setup mode.*✓"; then
    error "O firmware NÃO está em Setup Mode (Modo de Configuração)."
    echo
    warn "Para registrar as chaves PKI, o firmware precisa estar em Setup Mode."
    warn "Como habilitar o Setup Mode:"
    warn "  1. Reinicie e acesse a BIOS/UEFI (F2, F12, Del ou Esc durante o boot)"
    warn "  2. Na seção Secure Boot, procure 'Setup Mode', 'Clear Secure Boot Keys',"
    warn "     'Delete All Secure Boot Keys' ou opção similar"
    warn "  3. Apague as chaves existentes (isso habilita o Setup Mode)"
    warn "  4. Salve as configurações e reinicie o sistema"
    warn "  5. Execute este script novamente"
    echo
    warn "NOTA IMPORTANTE: Esta configuração usa lanzaboote — NÃO usa shim/MOK."
    warn "Não haverá tela do MOKmanager nem solicitação de senha de MOK."
    warn "O lanzaboote assina os binários EFI diretamente com chaves PKI próprias."
    echo
    die "Firmware não está em Setup Mode. Corrija e execute o script novamente."
  fi

  success "Firmware em Setup Mode. Prosseguindo com o registro de chaves."
  echo

  warn "As chaves Microsoft são incluídas para garantir compatibilidade com"
  warn "drivers de firmware assinados pela Microsoft (ex: drivers de GPU)."
  echo

  if sbctl enroll-keys --microsoft; then
    success "Chaves PKI registradas no firmware UEFI."
  else
    _exit_code=$?
    error "Falha ao registrar chaves PKI (código: $_exit_code)."
    warn "Possíveis causas:"
    warn "  • O firmware não aceitou as chaves (verifique o Setup Mode na UEFI)"
    warn "  • As chaves já foram registradas anteriormente (execute --verify-only)"
    warn "  • UEFI com restrição de escrita (tente sbctl enroll-keys --yes-this-might-brick-my-machine)"
    die "Registro de chaves falhou. Corrija e tente novamente."
  fi
  echo
fi

# ---------------------------------------------------------------------------
# Passo 3: Assinar binários EFI pendentes
# ---------------------------------------------------------------------------

if [[ "$OPT_ENROLL_ONLY" != "true" && "$OPT_VERIFY_ONLY" != "true" ]]; then
  info "==> Assinando binários EFI pendentes..."
  echo

  if sbctl sign-all; then
    success "Todos os binários EFI assinados."
  else
    warn "Alguns binários podem não ter sido assinados."
    warn "Execute 'sbctl verify' para verificar quais estão pendentes."
  fi
  echo

  # Verificar especificamente módulos NVIDIA (se presentes)
  NVIDIA_MODULES_DIR="/run/booted-system/kernel-modules/lib/modules"
  if [[ -d "$NVIDIA_MODULES_DIR" ]]; then
    NVIDIA_MODULES=$(find "$NVIDIA_MODULES_DIR" -name "nvidia*.ko*" 2>/dev/null || true)
    if [[ -n "$NVIDIA_MODULES" ]]; then
      info "Módulos NVIDIA detectados — verificando assinaturas..."
      # Os módulos NVIDIA estão incluídos no initrd, que é assinado pelo lanzaboote.
      # sbctl sign-all acima já deve ter assinado as entradas de boot relevantes.
      info "Os módulos NVIDIA são incluídos no initrd, assinado pelo lanzaboote."
      info "Use 'sbctl verify' para confirmar que o initrd está assinado."
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Passo 4: Verificar assinaturas
# ---------------------------------------------------------------------------

if [[ "$OPT_ENROLL_ONLY" != "true" ]]; then
  info "==> Verificando assinaturas dos binários EFI..."
  echo

  if sbctl verify; then
    echo
    success "Todos os binários EFI estão devidamente assinados!"
  else
    echo
    warn "Alguns binários EFI não estão assinados."
    warn "Execute 'nixos-rebuild switch' para regenerar e assinar os binários,"
    warn "em seguida, execute 'sudo sbctl sign-all' para assinar os pendentes."
  fi
  echo
fi

# ---------------------------------------------------------------------------
# Instruções finais
# ---------------------------------------------------------------------------

if [[ "$OPT_VERIFY_ONLY" != "true" ]]; then
  echo
  echo -e "${GREEN}${BOLD}Configuração do Secure Boot concluída!${RESET}"
  echo
  info "Próximos passos:"
  echo "  1. Reinicie o sistema"
  echo "  2. Acesse a UEFI/BIOS e ATIVE o Secure Boot"
  echo "  3. Salve e reinicie novamente"
  echo "  4. Verifique o estado com:"
  echo "       sudo sbctl status"
  echo "       sudo bash scripts/setup-secureboot.sh --verify-only"
  echo
  warn "Se o sistema não inicializar com o Secure Boot ativo, desative-o"
  warn "na UEFI e execute este script novamente."
fi
