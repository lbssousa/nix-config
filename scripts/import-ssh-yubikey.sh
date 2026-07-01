#!/usr/bin/env bash
# import-ssh-yubikey.sh — Importar chaves SSH residentes da YubiKey no live CD
#
# Baixa as chaves SSH residentes (ED25519-SK) armazenadas na YubiKey para
# ~/.ssh/, tornando-as disponíveis para autenticação SSH (GitHub, GitLab,
# acesso a servidores etc.) durante a instalação do NixOS.
#
# Passos executados:
#   1. Verificar pré-requisitos (ssh-keygen, YubiKey detectada via USB)
#   2. Baixar chaves residentes com ssh-keygen -K
#   3. Mover as chaves para ~/.ssh/ e ajustar permissões
#   4. Carregar as chaves no ssh-agent (se disponível)
#   5. Exibir as chaves públicas importadas para conferência
#
# Uso:
#   bash scripts/import-ssh-yubikey.sh [opções]
#
# Opções:
#   --ssh-dir <dir>   Diretório de destino das chaves (padrão: ~/.ssh)
#   --no-agent        Não tenta carregar as chaves no ssh-agent
#   --help, -h        Exibe ajuda e sai
#
# Após execução bem-sucedida, as chaves podem ser usadas para clonar
# repositórios via SSH (ex.: nix-keys), necessário para o install.sh.

set -euo pipefail

# ---------------------------------------------------------------------------
# Constantes
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
# Argumento parsing
# ---------------------------------------------------------------------------

OPT_SSH_DIR="$HOME/.ssh"
OPT_NO_AGENT=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ssh-dir)  OPT_SSH_DIR="$2"; shift 2 ;;
    --no-agent) OPT_NO_AGENT=true; shift ;;
    --help|-h)
      cat <<'EOF'
Uso:
  bash scripts/import-ssh-yubikey.sh [opções]

Opções:
  --ssh-dir <dir>   Diretório de destino das chaves (padrão: ~/.ssh)
  --no-agent        Não carrega as chaves no ssh-agent após a importação
  --help, -h        Exibe esta ajuda e sai

Descrição:
  Baixa as chaves SSH residentes (ED25519-SK) da YubiKey e as instala em
  ~/.ssh/ com as permissões corretas. As chaves são do tipo "resident":
  a chave privada é armazenada na YubiKey e apenas um stub é salvo em disco.
  Assim, qualquer operação de chave privada exige a presença física da YubiKey.

  O script usa ssh-keygen -K, que solicita o PIN da YubiKey interativamente.

Exemplos:
  # Uso padrão (importa para ~/.ssh/):
  bash scripts/import-ssh-yubikey.sh

  # Destino alternativo:
  bash scripts/import-ssh-yubikey.sh --ssh-dir /tmp/ssh-keys
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
echo -e "${BOLD}║   Importar chaves SSH residentes da YubiKey — live CD        ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
echo

# ---------------------------------------------------------------------------
# Passo 1: Verificar pré-requisitos
# ---------------------------------------------------------------------------

info "==> Passo 1: Verificar pré-requisitos"

if ! command -v ssh-keygen >/dev/null 2>&1; then
  error "ssh-keygen não encontrado."
  warn "Execute antes de continuar:"
  warn "  nix-shell -p openssh"
  die "ssh-keygen não encontrado."
fi
success "ssh-keygen: $(ssh-keygen -V 2>&1 | head -1 || echo 'disponível')"

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
# Passo 2: Baixar chaves residentes com ssh-keygen -K
# ---------------------------------------------------------------------------

info "==> Passo 2: Baixar chaves SSH residentes da YubiKey"
echo

# ssh-keygen -K grava os arquivos no diretório corrente; usamos um diretório
# temporário para depois mover para o destino final.
_tmpdir=$(mktemp -d)
trap 'rm -rf "$_tmpdir"' EXIT

info "O PIN da YubiKey será solicitado a seguir."
echo

# ssh-keygen -K:
#   Lê todas as chaves residentes do autenticador FIDO e grava arquivos
#   id_ed25519_sk_rk[_<handle>] e id_ed25519_sk_rk[_<handle>].pub no CWD.
#   O sufixo _rk indica "resident key" (chave cujo material privado fica
#   no hardware e nunca sai do dispositivo).
if ! (cd "$_tmpdir" && ssh-keygen -K); then
  echo
  error "ssh-keygen -K falhou."
  warn "Possíveis causas:"
  warn "  • Nenhuma chave residente gravada na YubiKey"
  warn "  • PIN incorreto ou cancelado"
  warn "  • YubiKey removida durante a operação"
  die "Falha ao baixar chaves residentes da YubiKey."
fi
echo

# Verificar se alguma chave foi gerada
_key_count=$(find "$_tmpdir" -name "id_ed25519_sk_rk*" ! -name "*.pub" | wc -l)
if [[ "$_key_count" -eq 0 ]]; then
  die "Nenhuma chave residente encontrada na YubiKey."
fi
info "$_key_count chave(s) residente(s) encontrada(s)."
echo

# ---------------------------------------------------------------------------
# Passo 3: Mover as chaves para ~/.ssh/ e ajustar permissões
# ---------------------------------------------------------------------------

info "==> Passo 3: Instalar chaves em ${OPT_SSH_DIR}/"

mkdir -p "$OPT_SSH_DIR"
chmod 700 "$OPT_SSH_DIR"

_installed=0
while IFS= read -r _privkey; do
  _pubkey="${_privkey}.pub"
  _basename=$(basename "$_privkey")
  _dst_priv="${OPT_SSH_DIR}/${_basename}"
  _dst_pub="${OPT_SSH_DIR}/${_basename}.pub"

  if [[ -f "$_dst_priv" ]]; then
    warn "Arquivo já existe, sobrescrevendo: $_dst_priv"
  fi

  cp "$_privkey" "$_dst_priv"
  chmod 600 "$_dst_priv"

  if [[ -f "$_pubkey" ]]; then
    cp "$_pubkey" "$_dst_pub"
    chmod 644 "$_dst_pub"
  fi

  success "Instalada: $_dst_priv"
  (( _installed++ )) || true
done < <(find "$_tmpdir" -name "id_ed25519_sk_rk*" ! -name "*.pub" | sort)

echo

# ---------------------------------------------------------------------------
# Passo 4: Carregar as chaves no ssh-agent
# ---------------------------------------------------------------------------

if [[ "$OPT_NO_AGENT" == "false" ]]; then
  info "==> Passo 4: Carregar chaves no ssh-agent"

  # Iniciar ssh-agent se não houver nenhum em execução
  if [[ -z "${SSH_AUTH_SOCK:-}" ]]; then
    info "SSH_AUTH_SOCK não definido — iniciando ssh-agent..."
    eval "$(ssh-agent -s)"
    success "ssh-agent iniciado (PID: $SSH_AGENT_PID)."
    warn "Para manter o agente nesta sessão, adicione ao shell:"
    warn "  eval \"\$(ssh-agent -s)\""
  fi

  _loaded=0
  while IFS= read -r _privkey; do
    _basename=$(basename "$_privkey")
    _dst="${OPT_SSH_DIR}/${_basename}"
    info "Adicionando ao agente: $_dst"
    if ssh-add "$_dst" 2>/dev/null; then
      success "Adicionada: $_basename"
      (( _loaded++ )) || true
    else
      warn "Falha ao adicionar $_basename ao agente (PIN pode ser necessário)."
    fi
  done < <(find "$_tmpdir" -name "id_ed25519_sk_rk*" ! -name "*.pub" | sort)

  [[ $_loaded -gt 0 ]] && info "$_loaded chave(s) carregada(s) no ssh-agent."
  echo
fi

# ---------------------------------------------------------------------------
# Passo 5: Exibir chaves públicas importadas
# ---------------------------------------------------------------------------

info "==> Passo 5: Chaves públicas importadas"
echo

while IFS= read -r _pubkey; do
  echo -e "${BOLD}$(basename "$_pubkey"):${RESET}"
  cat "$_pubkey"
  echo
done < <(find "$OPT_SSH_DIR" -name "id_ed25519_sk_rk*.pub" | sort)

echo -e "${GREEN}${BOLD}Chaves SSH residentes importadas com sucesso!${RESET}"
echo
info "As chaves estão em: $OPT_SSH_DIR"
info "Para verificar a conexão com o GitHub:"
echo "  ssh -T git@github.com"
echo
info "Próximo passo — instalação do sistema:"
echo "  bash scripts/install.sh"
echo
