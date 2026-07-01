#!/usr/bin/env bash
# import-gpg-yubikey.sh — Importar chave GPG da YubiKey no ambiente do live CD
#
# Prepara o ambiente GPG para operar com a chave privada armazenada na YubiKey,
# necessário para desbloquear o repositório nix-keys via git-crypt durante a
# instalação do NixOS.
#
# Passos executados:
#   1. Verificar pré-requisitos (gpg, YubiKey detectada via USB)
#   2. Iniciar o pcscd se não estiver em execução
#   3. Configurar scdaemon para usar PC/SC (disable-ccid), evitando conflito com pcscd
#   4. Importar a chave pública GPG: arquivo local > GitHub > servidor de chaves
#   5. Executar gpg --card-status para criar os stubs de chave privada
#   6. Definir confiança total (ultimate) para a chave importada
#   7. Verificar que os stubs foram criados e a chave está pronta para uso
#
# Uso:
#   bash scripts/import-gpg-yubikey.sh [opções]
#
# Opções:
#   --fingerprint <fp>  Fingerprint da chave GPG (padrão: BAC0B1B569777A733E37447FB10712C404063D38)
#   --pubkey <arquivo>  Importar chave pública de um arquivo local (.asc ou binário)
#   --github <usuário>  Importar chave pública do perfil GitHub (padrão: lbssousa)
#   --keyserver <url>   Servidor de chaves GPG (padrão: keyserver.ubuntu.com)
#   --no-trust          Não define confiança total para a chave importada
#   --help, -h          Exibe ajuda e sai
#
# Após execução bem-sucedida:
#   bash scripts/install.sh   (faz git-crypt unlock via GPG automaticamente)

set -euo pipefail

# ---------------------------------------------------------------------------
# Constantes
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
# Argumento parsing
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
Uso:
  bash scripts/import-gpg-yubikey.sh [opções]

Opções:
  --fingerprint <fp>  Fingerprint completo da chave GPG
                      Padrão: BAC0B1B569777A733E37447FB10712C404063D38
  --pubkey <arquivo>  Caminho para arquivo de chave pública (.asc ou binário)
  --github <usuário>  Importar chave pública do perfil GitHub (padrão: lbssousa)
                      Passe "" para desabilitar esta fonte
  --keyserver <url>   Servidor de chaves GPG (padrão: keyserver.ubuntu.com)
  --no-trust          Não define confiança total (ultimate) para a chave
  --help, -h          Exibe esta ajuda e sai

Fontes da chave pública (em ordem de prioridade):
  1. --pubkey <arquivo>   arquivo local
  2. --github <usuário>   https://github.com/<usuário>.gpg
  3. --keyserver <url>    gpg --recv-keys <fingerprint>

Exemplos:
  # Uso padrão (importa do GitHub lbssousa):
  bash scripts/import-gpg-yubikey.sh

  # Com arquivo de chave pública local:
  bash scripts/import-gpg-yubikey.sh --pubkey /mnt/usb/pubkey.asc

  # Apenas via servidor de chaves, sem GitHub:
  bash scripts/import-gpg-yubikey.sh --github "" --keyserver keys.openpgp.org

Após execução bem-sucedida:
  bash scripts/install.sh
  (o script fará git-crypt unlock automaticamente via GPG/YubiKey)
EOF
      exit 0 ;;
    *) die "Opção desconhecida: $1. Use --help para ver as opções." ;;
  esac
done

# ---------------------------------------------------------------------------
# Cabeçalho
# ---------------------------------------------------------------------------

echo
echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║     Importar chave GPG da YubiKey — preparação de install    ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
echo

# ---------------------------------------------------------------------------
# Passo 1: Verificar pré-requisitos
# ---------------------------------------------------------------------------

info "==> Passo 1: Verificar pré-requisitos"

if ! command -v gpg >/dev/null 2>&1; then
  error "gpg não encontrado."
  warn "Execute antes de continuar:"
  warn "  nix-shell -p gnupg"
  die "gpg não encontrado."
fi
success "gpg: $(gpg --version | head -1)"

if command -v lsusb >/dev/null 2>&1; then
  if ! lsusb 2>/dev/null | grep -qi ":${YUBICO_USB_VENDOR}\b\|${YUBICO_USB_VENDOR}:"; then
    die "YubiKey não detectada (lsusb não encontrou dispositivo Yubico). Insira a YubiKey e tente novamente."
  fi
  _yubikey_line=$(lsusb 2>/dev/null | grep -i "${YUBICO_USB_VENDOR}:" | head -1)
  success "YubiKey detectada: $_yubikey_line"
else
  warn "lsusb não disponível — verificação de hardware ignorada."
fi
echo

# ---------------------------------------------------------------------------
# Passo 2: Iniciar pcscd
# ---------------------------------------------------------------------------

info "==> Passo 2: Iniciar pcscd (PC/SC daemon)"

_pcscd_running=false

if systemctl is-active --quiet pcscd 2>/dev/null; then
  success "pcscd já está em execução."
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
    # Aguardar até 5 s para o pcscd ficar ativo
    for _i in 1 2 3 4 5; do
      if systemctl is-active --quiet pcscd 2>/dev/null; then
        _pcscd_running=true
        break
      fi
      sleep 1
    done
    [[ "$_pcscd_running" == "true" ]] && success "pcscd iniciado." \
      || warn "pcscd iniciado mas não ficou ativo em 5 s."
  else
    warn "Não foi possível iniciar pcscd automaticamente."
    warn "Tente manualmente: run0 systemctl start pcscd"
  fi
else
  warn "pcscd não encontrado. Execute: nix-shell -p pcsclite"
fi
echo

# ---------------------------------------------------------------------------
# Passo 3: Configurar scdaemon
# ---------------------------------------------------------------------------

info "==> Passo 3: Configurar scdaemon"

_gnupg_home="${GNUPGHOME:-$HOME/.gnupg}"
mkdir -p "$_gnupg_home"
chmod 700 "$_gnupg_home"

_scdaemon_conf="$_gnupg_home/scdaemon.conf"

if [[ "$_pcscd_running" == "true" ]]; then
  # disable-ccid: redireciona o scdaemon para usar PC/SC (pcscd) em vez de
  # acessar o USB diretamente via CCID. Evita que pcscd e scdaemon disputem
  # o mesmo dispositivo USB, o que causaria "card error" ou "no card".
  if ! grep -q "^disable-ccid" "$_scdaemon_conf" 2>/dev/null; then
    echo "disable-ccid" >> "$_scdaemon_conf"
    success "scdaemon.conf: disable-ccid adicionado."
  else
    success "scdaemon.conf: disable-ccid já configurado."
  fi
else
  warn "pcscd não está ativo — disable-ccid não configurado."
  warn "Se gpg --card-status falhar, inicie o pcscd e repita o script."
fi

# Reiniciar o agente GPG para que o scdaemon releia a configuração
gpgconf --kill gpg-agent 2>/dev/null || true
success "gpg-agent reiniciado."
echo

# ---------------------------------------------------------------------------
# Passo 4: Importar chave pública GPG
# ---------------------------------------------------------------------------

info "==> Passo 4: Importar chave pública GPG"

_key_imported=false

# Verificar se o fingerprint já está no keyring
if gpg --list-keys "$OPT_FINGERPRINT" >/dev/null 2>&1; then
  success "Fingerprint $OPT_FINGERPRINT já está no keyring — importação ignorada."
  _key_imported=true
fi

# Fonte 1: arquivo local
if [[ "$_key_imported" == "false" && -n "$OPT_PUBKEY" ]]; then
  [[ ! -f "$OPT_PUBKEY" ]] && die "--pubkey: arquivo não encontrado: $OPT_PUBKEY"
  info "Importando de arquivo local: $OPT_PUBKEY"
  if gpg --import "$OPT_PUBKEY" 2>&1; then
    success "Chave pública importada do arquivo."
    _key_imported=true
  else
    warn "Falha ao importar do arquivo local. Tentando próxima fonte..."
  fi
fi

# Fonte 2: GitHub
if [[ "$_key_imported" == "false" && -n "$OPT_GITHUB" ]]; then
  if command -v curl >/dev/null 2>&1; then
    info "Importando do GitHub: https://github.com/${OPT_GITHUB}.gpg"
    if curl -fsSL "https://github.com/${OPT_GITHUB}.gpg" | gpg --import; then
      success "Chave pública importada do GitHub (${OPT_GITHUB})."
      _key_imported=true
    else
      warn "Falha ao importar do GitHub. Tentando servidor de chaves..."
    fi
  else
    warn "curl não disponível — fonte GitHub ignorada."
  fi
fi

# Fonte 3: servidor de chaves
if [[ "$_key_imported" == "false" ]]; then
  info "Buscando no servidor de chaves: $OPT_KEYSERVER"
  info "Fingerprint: $OPT_FINGERPRINT"
  if gpg --keyserver "$OPT_KEYSERVER" --recv-keys "$OPT_FINGERPRINT"; then
    success "Chave pública obtida do servidor de chaves."
    _key_imported=true
  else
    die "Não foi possível obter a chave pública por nenhuma das fontes configuradas."
  fi
fi

# Confirmar que o fingerprint esperado está no keyring
if ! gpg --list-keys "$OPT_FINGERPRINT" >/dev/null 2>&1; then
  error "Fingerprint $OPT_FINGERPRINT não encontrado no keyring após a importação."
  warn "A chave importada pode ser de um fingerprint diferente."
  warn "Liste as chaves disponíveis com: gpg --list-keys"
  die "Fingerprint não encontrado no keyring."
fi
echo

# ---------------------------------------------------------------------------
# Passo 5: Criar stubs de chave privada via gpg --card-status
# ---------------------------------------------------------------------------

info "==> Passo 5: Criar stubs de chave privada (gpg --card-status)"
echo

if ! gpg --card-status; then
  echo
  error "gpg --card-status falhou."
  warn "Verifique:"
  warn "  • YubiKey inserida"
  warn "  • pcscd em execução: systemctl status pcscd"
  warn "  • Configuração do scdaemon: cat ~/.gnupg/scdaemon.conf"
  die "Falha ao ler o cartão YubiKey."
fi
echo

# ---------------------------------------------------------------------------
# Passo 6: Definir confiança total (ultimate)
# ---------------------------------------------------------------------------

if [[ "$OPT_NO_TRUST" == "false" ]]; then
  info "==> Passo 6: Definir confiança total para a chave"

  if echo "${OPT_FINGERPRINT}:6:" | gpg --import-ownertrust; then
    success "Confiança total (ultimate) definida para $OPT_FINGERPRINT."
  else
    warn "Não foi possível definir a confiança automaticamente."
    warn "Execute manualmente:"
    warn "  gpg --edit-key $OPT_FINGERPRINT"
    warn "  trust → 5 (eu confio plenamente) → quit"
  fi
  echo
fi

# ---------------------------------------------------------------------------
# Passo 7: Verificação final
# ---------------------------------------------------------------------------

info "==> Passo 7: Verificação final"
echo

gpg --list-secret-keys --keyid-format long "$OPT_FINGERPRINT" 2>/dev/null \
  || gpg --list-secret-keys --keyid-format long

echo

# Stubs de chave no cartão aparecem como sec> ou ssb> (o '>' indica card stub)
if gpg --list-secret-keys "$OPT_FINGERPRINT" 2>/dev/null | grep -qE '^(sec|ssb)>'; then
  success "Stubs de chave detectados (sec> / ssb> — chave privada na YubiKey)."
else
  warn "Nenhum stub de cartão detectado (esperado: sec> ou ssb>)."
  warn "O git-crypt unlock pode falhar. Verifique: gpg --list-secret-keys"
fi

echo
echo -e "${GREEN}${BOLD}Ambiente GPG pronto para uso com a YubiKey!${RESET}"
echo
info "Próximos passos:"
echo "  bash scripts/install.sh"
echo "  (o script fará git-crypt unlock automaticamente via GPG)"
echo
echo "  Ou, para desbloquear o nix-keys manualmente:"
echo "  cd /caminho/para/nix-keys && git-crypt unlock"
echo
