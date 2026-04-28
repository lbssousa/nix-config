#!/usr/bin/env bash
# setup-secureboot.sh — Configurar Secure Boot e assinar módulos do kernel (NVIDIA)
#
# Este script realiza as etapas pós-instalação necessárias para o Secure Boot
# funcionar com o lanzaboote:
#
#   1. Verificar o estado atual do Secure Boot e do sbctl
#   2. Verificar banco de chaves PKI (sbctl/lanzaboote)
#   3. Assinar todos os binários EFI ANTES do registro no firmware
#   4. Verificar que todos os binários estão assinados (pré-condição para enrollment)
#   5. Registrar as chaves PKI no firmware UEFI (sbctl enroll-keys)
#   6. Verificação final das assinaturas
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

verify_signed_efi_binaries() {
  local _verify_output
  local _verify_exit
  local _unsigned_actionable

  if _verify_output=$(sbctl verify 2>&1); then
    _verify_exit=0
  else
    _verify_exit=$?
  fi
  echo "$_verify_output"

  # Em algumas versões do sbctl, o exit code pode não refletir binários pendentes.
  # Então também validamos o conteúdo textual da saída.
  if echo "$_verify_output" | grep -Eiq 'is not signed|not signed'; then
    _unsigned_actionable=$(extract_unsigned_efi_paths "$_verify_output")
    if [[ -n "$_unsigned_actionable" ]]; then
      return 1
    fi

    warn "Há entradas 'not signed' não acionáveis (ex.: initrd-*.efi não-PE); ignorando."
    return 0
  fi

  return $_verify_exit
}

extract_unsigned_efi_paths() {
  local _verify_output="$1"

  echo "$_verify_output" \
    | grep -E 'not signed' \
    | grep -Eo '/[^[:space:]]+\.efi' \
    | grep -Ev '/boot/EFI/nixos/initrd-[^/]+\.efi$' \
    | sort -u
}

sign_explicit_efi_path() {
  local _path="$1"
  local _sign_output

  if [[ ! -f "$_path" ]]; then
    warn "Arquivo EFI não encontrado para assinatura explícita: $_path"
    return 1
  fi

  # Os artefatos /boot/EFI/nixos/initrd-*.efi não são imagens PE/COFF assináveis.
  # O que precisa estar assinado para boot é o UKI em /boot/EFI/Linux/*.efi.
  if [[ "$_path" =~ ^/boot/EFI/nixos/initrd-.*\.efi$ ]]; then
    warn "Ignorando artefato não-assinável: $_path"
    return 3
  fi

  # Algumas versões usam 'sbctl sign -s <path>', outras aceitam 'sbctl sign <path>'.
  if _sign_output=$(sbctl sign -s "$_path" 2>&1); then
    return 0
  fi

  if echo "$_sign_output" | grep -qi 'unrecognized PE machine'; then
    warn "Arquivo não é uma imagem PE/COFF assinável: $_path"
    return 3
  fi

  if _sign_output=$(sbctl sign "$_path" 2>&1); then
    return 0
  fi

  if echo "$_sign_output" | grep -qi 'unrecognized PE machine'; then
    warn "Arquivo não é uma imagem PE/COFF assinável: $_path"
    return 3
  fi

  return 1
}

try_fix_unsigned_efi_binaries() {
  local _verify_output="$1"
  local _unsigned_paths
  local _path
  local _sign_rc
  local _fixed_any=false
  local _failed_any=false

  _unsigned_paths=$(extract_unsigned_efi_paths "$_verify_output")
  if [[ -z "$_unsigned_paths" ]]; then
    return 1
  fi

  warn "Foram detectados binários EFI não assinados. Tentando assinatura explícita..."
  while IFS= read -r _path; do
    [[ -z "$_path" ]] && continue
    if sign_explicit_efi_path "$_path"; then
      success "Assinatura explícita aplicada: $_path"
      _fixed_any=true
    else
      _sign_rc=$?
      if [[ $_sign_rc -eq 3 ]]; then
        warn "Arquivo não assinável pelo sbctl (ignorado): $_path"
      else
        warn "Falha ao assinar explicitamente: $_path"
        _failed_any=true
      fi
    fi
  done <<< "$_unsigned_paths"

  if [[ "$_fixed_any" == "true" && "$_failed_any" == "false" ]]; then
    return 0
  fi

  if [[ "$_fixed_any" == "true" ]]; then
    return 2
  fi

  return 1
}

sign_nixos_efi_binaries_explicitly() {
  local _nixos_efi_dir=/boot/EFI/nixos
  local _path
  local _base
  local _sign_rc
  local _found_any=false

  if [[ ! -d "$_nixos_efi_dir" ]]; then
    return 0
  fi

  info "==> Assinando explicitamente binários em $_nixos_efi_dir (fallback para sign-all)..."
  for _path in "$_nixos_efi_dir"/*.efi; do
    if [[ -f "$_path" ]]; then
      _found_any=true
      _base=$(basename "$_path")

      if [[ "$_base" == initrd-* ]]; then
        warn "Ignorando $_path (artefato initrd não assinável por sbctl)."
        continue
      fi

      if sign_explicit_efi_path "$_path"; then
        success "Assinado explicitamente: $_path"
      else
        _sign_rc=$?
        if [[ $_sign_rc -eq 3 ]]; then
          warn "Ignorado (não assinável por sbctl): $_path"
        else
          warn "Falha ao assinar explicitamente: $_path"
        fi
      fi
    fi
  done

  if [[ "$_found_any" == "false" ]]; then
    warn "Nenhum .efi encontrado em $_nixos_efi_dir para assinatura explícita."
  fi

  echo
  return 0
}

unlock_efivarfs_immutables() {
  local _efivarfs=/sys/firmware/efi/efivars
  local _had_immutable=false
  local _cleared_any=false
  local _f

  if [[ ! -d "$_efivarfs" ]]; then
    warn "efivarfs não está montado em $_efivarfs."
    return 1
  fi

  if ! command -v chattr >/dev/null 2>&1; then
    warn "'chattr' não encontrado. Não foi possível desbloquear variáveis EFI imutáveis."
    return 1
  fi

  for _f in \
    "$_efivarfs"/PK-* \
    "$_efivarfs"/KEK-* \
    "$_efivarfs"/db-* \
    "$_efivarfs"/dbx-*; do
    if [ -f "$_f" ]; then
      if lsattr "$_f" 2>/dev/null | awk '{print $1}' | grep -q 'i'; then
        _had_immutable=true
      fi

      # Tenta remover imutabilidade de forma idempotente.
      if chattr -i "$_f" 2>/dev/null; then
        _cleared_any=true
      fi
    fi
  done

  if [ "$_had_immutable" = "true" ]; then
    warn "Atributo imutável (chattr +i) detectado e tratado nas variáveis EFI."
    warn "Isso ocorre em alguns firmwares que bloqueiam efivars mesmo em Setup Mode."
    echo
  fi

  if [ "$_cleared_any" = "true" ]; then
    return 0
  fi

  return 1
}

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
  --sign-only     Apenas assina os binários EFI (e verifica antes de registrar)
  --verify-only   Apenas verifica se todos os binários estão assinados
  --help, -h      Exibe esta ajuda e sai

Passos para configurar o Secure Boot:
  1. Inicialize o sistema com o Secure Boot DESATIVADO (Setup Mode na UEFI)
     (para ativar o Setup Mode: BIOS → Secure Boot → apagar chaves existentes)
  2. Execute este script para assinar binários e registrar chaves:
       sudo bash scripts/setup-secureboot.sh
     O script:
       a) Assina todos os binários EFI com as chaves PKI (sign-all)
       b) Verifica que TODOS os binários estão assinados (obrigatório)
       c) Registra as chaves no firmware UEFI (enroll-keys --microsoft)
  3. Reinicie e ative o Secure Boot na UEFI/BIOS
  4. Verifique se tudo está correto:
       sudo bash scripts/setup-secureboot.sh --verify-only

NOTA IMPORTANTE — Lanzaboote vs. MOK/shim:
  Esta configuração usa lanzaboote, que NÃO utiliza shim nem MOK.
  • Não haverá tela azul do MOKmanager durante o boot
  • Não será solicitada nenhuma senha de MOK
  • A ausência do MOK é ESPERADA e CORRETA com lanzaboote
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
# Passo 2: Verificar banco de chaves PKI
# ---------------------------------------------------------------------------

# Verificar se o banco de chaves sbctl está acessível.
# A configuração do host cria um symlink /var/lib/sbctl → pkiBundle (ex: /persist/etc/secureboot)
# via systemd-tmpfiles (regra "L+ /var/lib/sbctl"). Se as chaves não forem encontradas,
# o sbctl não consegue assinar binários nem registrar chaves no firmware.
# Usa verificação via sistema de arquivos para robustez (independente de locale/encoding).
_sbctl_db=/var/lib/sbctl
if [[ ! -d "$_sbctl_db/keys" ]] && [[ ! -f "$_sbctl_db/GUID" ]]; then
  error "Banco de chaves sbctl não encontrado em $_sbctl_db."
  warn "As chaves PKI devem estar em /var/lib/sbctl (→ /persist/etc/secureboot)."
  warn "Verifique se:"
  warn "  • A instalação foi concluída com sucesso (install.sh criou as chaves)"
  warn "  • O symlink /var/lib/sbctl → /persist/etc/secureboot existe"
  warn "  • O sistema foi reconstruído com 'nixos-rebuild switch'"
  die "Banco de chaves não encontrado. Verifique a instalação."
fi
_sbctl_status_output=$(sbctl status 2>&1)

# ---------------------------------------------------------------------------
# Passo 3: Assinar binários EFI ANTES do registro no firmware
# ---------------------------------------------------------------------------
# Assinar antes de registrar garante que, se o processo de assinatura falhar
# (chave ausente, binário inválido), o firmware não é alterado desnecessariamente.

if [[ "$OPT_ENROLL_ONLY" != "true" && "$OPT_VERIFY_ONLY" != "true" ]]; then
  info "==> Assinando binários EFI com as chaves PKI..."
  echo

  if sbctl sign-all; then
    success "Todos os binários EFI assinados."
  else
    warn "Alguns binários podem não ter sido assinados."
    warn "Execute 'sbctl verify' para verificar quais estão pendentes."
  fi
  sign_nixos_efi_binaries_explicitly
  echo

  # Verificar assinaturas ANTES de prosseguir com o registro no firmware.
  # Se houver binários não assinados, o boot com Secure Boot ativo falhará.
  info "==> Verificando assinaturas antes do registro no firmware..."
  if _verify_before_enroll_output=$(verify_signed_efi_binaries); then
    echo "$_verify_before_enroll_output"
  else
    echo "$_verify_before_enroll_output"
    echo

    if try_fix_unsigned_efi_binaries "$_verify_before_enroll_output"; then
      echo
      info "==> Revalidando assinaturas EFI após correção automática..."
      if ! verify_signed_efi_binaries; then
        echo
        error "Há binários EFI sem assinatura válida após tentativa de correção automática."
        warn "O Secure Boot falhará se o firmware for configurado agora."
        warn "Execute os seguintes comandos para corrigir e tente novamente:"
        warn "  1. sudo nixos-rebuild switch   (regenera e assina os stubs lanzaboote)"
        warn "  2. sudo sbctl sign-all         (assina binários adicionais)"
        warn "  3. sudo bash scripts/setup-secureboot.sh   (execute este script novamente)"
        die "Assinaturas incompletas. Corrija antes de registrar as chaves no firmware."
      fi
    else
      error "Há binários EFI sem assinatura válida."
      warn "O Secure Boot falhará se o firmware for configurado agora."
      warn "Execute os seguintes comandos para corrigir e tente novamente:"
      warn "  1. sudo nixos-rebuild switch   (regenera e assina os stubs lanzaboote)"
      warn "  2. sudo sbctl sign-all         (assina binários adicionais)"
      warn "  3. sudo bash scripts/setup-secureboot.sh   (execute este script novamente)"
      die "Assinaturas incompletas. Corrija antes de registrar as chaves no firmware."
    fi
  fi
  success "Todos os binários EFI estão assinados. Prosseguindo com o registro."
  echo
fi

# ---------------------------------------------------------------------------
# Passo 4: Registrar chaves PKI no firmware UEFI
# ---------------------------------------------------------------------------

if [[ "$OPT_SIGN_ONLY" != "true" && "$OPT_VERIFY_ONLY" != "true" ]]; then
  info "==> Registrando chaves PKI no firmware UEFI..."
  echo

  # Verificar se o firmware está em Setup Mode (pré-requisito para enroll-keys)
  # Com lanzaboote, NÃO existe senha de MOK nem tela do MOKmanager.
  # O lanzaboote usa suas próprias chaves PKI (PK/KEK/db) — não usa shim/MOK.
  # Usa verificação via EFI efivars para robustez (independente de locale/encoding do sbctl).
  _in_setup_mode=false
  # GUID da variável EFI global (EFI_GLOBAL_VARIABLE) — padrão UEFI Spec Apêndice B
  _EFI_GLOBAL_GUID="8be4df61-93ca-11d2-aa0d-00e098032b8c"
  # Tenta verificar pelo conteúdo da variável EFI SetupMode (1 = Setup Mode ativo)
  if [[ -f /sys/firmware/efi/efivars/SetupMode-${_EFI_GLOBAL_GUID} ]]; then
    # O byte de atributo é os primeiros 4 bytes; o valor é o 5º byte (0x01 = Setup Mode)
    _setup_byte=$(od -An -tx1 -j4 -N1 \
      /sys/firmware/efi/efivars/SetupMode-${_EFI_GLOBAL_GUID} 2>/dev/null \
      | tr -d ' \n')
    [[ "$_setup_byte" == "01" ]] && _in_setup_mode=true
  fi
  # Fallback: verificar saída do sbctl (padrões sem caracteres Unicode especiais)
  if [[ "$_in_setup_mode" == "false" ]]; then
    if echo "$_sbctl_status_output" | grep -qi "setup mode[[:space:]]*:.*enabled\|setup mode[[:space:]]*:.*yes"; then
      _in_setup_mode=true
    fi
  fi

  if [[ "$_in_setup_mode" == "false" ]]; then
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

  # Alguns firmwares marcam efivars como imutáveis mesmo em Setup Mode.
  # Faz uma tentativa preventiva de desbloqueio antes do enrollment.
  unlock_efivarfs_immutables || true

  warn "As chaves Microsoft são incluídas para garantir compatibilidade com"
  warn "drivers de firmware assinados pela Microsoft (ex: drivers de GPU)."
  echo

  if _enroll_output=$(sbctl enroll-keys --microsoft 2>&1); then
    _enroll_exit=0
  else
    _enroll_exit=$?
  fi
  echo "$_enroll_output"

  if [[ $_enroll_exit -eq 0 ]]; then
    success "Chaves PKI registradas no firmware UEFI."
  else
    if echo "$_enroll_output" | grep -Eiq 'file is immutable|chattr -i files in efivarfs'; then
      warn "Falha detectada por efivars imutáveis. Tentando desbloquear e repetir enrollment..."
      unlock_efivarfs_immutables || true

      if _retry_output=$(sbctl enroll-keys --microsoft 2>&1); then
        _retry_exit=0
      else
        _retry_exit=$?
      fi
      echo "$_retry_output"

      if [[ $_retry_exit -eq 0 ]]; then
        success "Chaves PKI registradas no firmware UEFI (após desbloquear efivars)."
      else
        error "Falha ao registrar chaves PKI após tentativa de desbloqueio (código: $_retry_exit)."
        warn "Possíveis causas:"
        warn "  • O firmware não aceitou as chaves (verifique o Setup Mode na UEFI)"
        warn "  • As chaves já foram registradas anteriormente (execute --verify-only)"
        warn "  • UEFI com restrição de escrita (tente sbctl enroll-keys --yes-this-might-brick-my-machine)"
        die "Registro de chaves falhou. Corrija e tente novamente."
      fi
    else
      error "Falha ao registrar chaves PKI (código: $_enroll_exit)."
      warn "Possíveis causas:"
      warn "  • O firmware não aceitou as chaves (verifique o Setup Mode na UEFI)"
      warn "  • As chaves já foram registradas anteriormente (execute --verify-only)"
      warn "  • UEFI com restrição de escrita (tente sbctl enroll-keys --yes-this-might-brick-my-machine)"
      die "Registro de chaves falhou. Corrija e tente novamente."
    fi
  fi
  echo
fi

# ---------------------------------------------------------------------------
# Passo 5: Verificação final das assinaturas
# ---------------------------------------------------------------------------

if [[ "$OPT_ENROLL_ONLY" != "true" && "$OPT_SIGN_ONLY" != "true" ]]; then
  info "==> Verificação final dos binários EFI..."
  echo

  if verify_signed_efi_binaries; then
    echo
    success "Todos os binários EFI estão devidamente assinados!"
  else
    echo
    warn "Alguns binários EFI não estão assinados (verificação pós-registro)."
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
