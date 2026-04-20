#!/usr/bin/env bash
# install.sh — Script de instalação automática do NixOS
#
# Automatiza os passos descritos em INSTALLATION.md:
#   1. Habilita Flakes no ambiente live
#   2. Seleciona o host e o disco de destino
#   3. Particiona e formata o disco com disko
#   4. Gera o hostId ZFS e atualiza hardware-configuration.nix
#   5. Cria o arquivo de usuário a partir do skeleton
#   6. Adiciona o arquivo de usuário ao índice do git (git add --force)
#   7. Atualiza configuration.nix com o import do usuário
#   8. Instala o NixOS
#   9. Define senhas via nixos-enter
#
# Uso:
#   bash scripts/install.sh [--host <hostname>] [--disk <device>]
#                           [--user <username>] [--full-name "<Nome Completo>"]
#                           [--non-interactive]
#
# Opções:
#   --host            Nome do host NixOS (ex: barbudus, bigodon)
#   --disk            Dispositivo de disco (ex: /dev/nvme0n1, /dev/sda)
#   --user            Nome do usuário a criar
#   --full-name       Nome completo do usuário (entre aspas)
#   --non-interactive Não faz perguntas; falha se informações obrigatórias
#                     não forem fornecidas via flags

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

confirm() {
  # confirm "mensagem" → retorna 0 se usuário digitar s/S/y/Y
  local msg="$1"
  local resp
  echo -e "${YELLOW}${msg}${RESET} [s/N] " >&2
  read -r resp
  [[ "$resp" =~ ^[sSyY]$ ]]
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Comando '$1' não encontrado. Certifique-se de estar no ambiente live do NixOS."
}

# ---------------------------------------------------------------------------
# Argumento parsing
# ---------------------------------------------------------------------------

OPT_HOST=""
OPT_DISK=""
OPT_USER=""
OPT_FULL_NAME=""
OPT_NON_INTERACTIVE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)           OPT_HOST="$2";          shift 2 ;;
    --disk)           OPT_DISK="$2";          shift 2 ;;
    --user)           OPT_USER="$2";          shift 2 ;;
    --full-name)      OPT_FULL_NAME="$2";     shift 2 ;;
    --non-interactive) OPT_NON_INTERACTIVE=true; shift ;;
    *) die "Opção desconhecida: $1" ;;
  esac
done

ask() {
  # ask VAR "prompt" ["default"]
  local var="$1" prompt="$2" default="${3:-}"
  if [[ "$OPT_NON_INTERACTIVE" == "true" ]]; then
    [[ -n "${!var:-}" ]] || die "Modo não-interativo: '$var' não definido. Use --${var//_/-} <valor>."
    return
  fi
  local current="${!var:-$default}"
  local display_default=""
  [[ -n "$current" ]] && display_default=" [${current}]"
  echo -ne "${BOLD}${prompt}${display_default}: ${RESET}"
  local input
  read -r input
  # Se não digitou nada, mantém o valor já definido (via flag ou default)
  if [[ -n "$input" ]]; then
    printf -v "$var" '%s' "$input"
  elif [[ -z "${!var:-}" && -n "$default" ]]; then
    printf -v "$var" '%s' "$default"
  fi
}

# ---------------------------------------------------------------------------
# 0. Pré-requisitos
# ---------------------------------------------------------------------------

echo
echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║          Instalação do NixOS — Script Automatizado           ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
echo

# Detectar o diretório raiz da configuração (onde este script está)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

info "Diretório de configuração: $CONFIG_DIR"
cd "$CONFIG_DIR"

require_cmd git
require_cmd nix
require_cmd lsblk
require_cmd sed

# Habilitar Flakes no ambiente live (idempotente)
NIX_CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nix"
mkdir -p "$NIX_CONF_DIR"
if ! grep -q "experimental-features" "$NIX_CONF_DIR/nix.conf" 2>/dev/null; then
  echo "experimental-features = nix-command flakes" >> "$NIX_CONF_DIR/nix.conf"
  success "Flakes habilitados em $NIX_CONF_DIR/nix.conf"
else
  info "Flakes já estão habilitados."
fi

# ---------------------------------------------------------------------------
# 1. Selecionar o host
# ---------------------------------------------------------------------------

echo
info "==> Passo 1: Selecionar o host"

# Detectar hosts disponíveis
mapfile -t AVAILABLE_HOSTS < <(find "$CONFIG_DIR/hosts" -maxdepth 1 -mindepth 1 -type d -exec basename {} \; | sort)

if [[ ${#AVAILABLE_HOSTS[@]} -eq 0 ]]; then
  die "Nenhum host encontrado em $CONFIG_DIR/hosts/"
fi

echo "Hosts disponíveis:"
for h in "${AVAILABLE_HOSTS[@]}"; do
  echo "  - $h"
done

ask OPT_HOST "Nome do host" "${AVAILABLE_HOSTS[0]}"
[[ -n "$OPT_HOST" ]] || die "Nome do host é obrigatório."
[[ -d "$CONFIG_DIR/hosts/$OPT_HOST" ]] || die "Host '$OPT_HOST' não encontrado em $CONFIG_DIR/hosts/"

success "Host selecionado: $OPT_HOST"

HOST="$OPT_HOST"
DISKO_FILE="$CONFIG_DIR/hosts/$HOST/disko.nix"
HW_FILE="$CONFIG_DIR/hosts/$HOST/hardware-configuration.nix"
CFG_FILE="$CONFIG_DIR/hosts/$HOST/configuration.nix"

# ---------------------------------------------------------------------------
# 2. Selecionar o disco
# ---------------------------------------------------------------------------

echo
info "==> Passo 2: Selecionar o disco de instalação"

echo "Discos disponíveis:"
lsblk -d -o NAME,SIZE,MODEL,TYPE | grep disk || true
echo

ask OPT_DISK "Dispositivo de disco (ex: /dev/nvme0n1)"
[[ -n "$OPT_DISK" ]] || die "Dispositivo de disco é obrigatório."
[[ -b "$OPT_DISK" ]] || die "Dispositivo '$OPT_DISK' não encontrado ou não é um bloco de dispositivo."

success "Disco selecionado: $OPT_DISK"
DISK="$OPT_DISK"

# Atualizar disko.nix com o disco correto
CURRENT_DISK=$(grep -oP '(?<=device = ")[^"]+' "$DISKO_FILE" || true)
if [[ "$CURRENT_DISK" != "$DISK" ]]; then
  info "Atualizando device em $DISKO_FILE: $CURRENT_DISK → $DISK"
  sed -i "s|device = \"[^\"]*\"|device = \"$DISK\"|g" "$DISKO_FILE"
  success "disko.nix atualizado."
else
  info "disko.nix já está configurado para $DISK."
fi

# ---------------------------------------------------------------------------
# 3. Particionar e formatar o disco
# ---------------------------------------------------------------------------

echo
info "==> Passo 3: Particionar e formatar o disco"

warn "⚠️  ATENÇÃO: o comando abaixo IRÁ APAGAR TODOS OS DADOS DE $DISK!"
if ! confirm "Continuar com a formatação de $DISK?"; then
  die "Formatação cancelada pelo usuário."
fi

info "Executando disko..."
sudo nix run github:nix-community/disko -- --mode disko "$DISKO_FILE"
success "Disco particionado e formatado com sucesso."

# ---------------------------------------------------------------------------
# 4. Gerar hostId ZFS e atualizar hardware-configuration.nix
# ---------------------------------------------------------------------------

echo
info "==> Passo 4: Configurar hostId ZFS"

HOST_ID=$(head -c 8 /dev/urandom | od -A n -t x1 | tr -d ' \n')
info "hostId gerado: $HOST_ID"

# Atualizar (ou inserir) networking.hostId em hardware-configuration.nix
if grep -q 'networking\.hostId' "$HW_FILE"; then
  sed -i "s|networking\.hostId = \"[^\"]*\"|networking.hostId = \"$HOST_ID\"|g" "$HW_FILE"
  success "networking.hostId atualizado em $HW_FILE"
else
  # Inserir antes da linha nixpkgs.hostPlatform ou no final do bloco raiz
  if grep -q 'nixpkgs\.hostPlatform' "$HW_FILE"; then
    sed -i "s|nixpkgs\.hostPlatform|networking.hostId = \"$HOST_ID\"; # gerado por install.sh\n  nixpkgs.hostPlatform|" "$HW_FILE"
  else
    warn "Não foi possível localizar o ponto de inserção em $HW_FILE."
    warn "Adicione manualmente: networking.hostId = \"$HOST_ID\";"
  fi
  success "networking.hostId inserido em $HW_FILE"
fi

# Gerar hardware-configuration.nix real e preservar as partes essenciais
info "Gerando hardware-configuration.nix via nixos-generate-config..."
GENERATED_HW=/tmp/nixos-generate-config-hw.nix
sudo nixos-generate-config --no-filesystems --root /mnt --show-hardware-config > "$GENERATED_HW" 2>/dev/null || {
  warn "nixos-generate-config falhou ou não está disponível. Mantendo o template existente."
  GENERATED_HW=""
}

if [[ -n "$GENERATED_HW" && -s "$GENERATED_HW" ]]; then
  # Preservar as linhas essenciais do template existente que o gerador omite
  TMP_HW=$(mktemp /tmp/hw-XXXXXX.nix)
  # Usar o arquivo gerado como base
  cp "$GENERATED_HW" "$TMP_HW"

  # Garantir que hostId está presente
  if ! grep -q 'networking\.hostId' "$TMP_HW"; then
    sed -i "/nixpkgs\.hostPlatform/i\\  networking.hostId = \"$HOST_ID\";" "$TMP_HW"
  else
    sed -i "s|networking\.hostId = \"[^\"]*\"|networking.hostId = \"$HOST_ID\"|g" "$TMP_HW"
  fi

  # Garantir que ./disko.nix está nos imports
  if ! grep -q 'disko\.nix\|./disko' "$TMP_HW"; then
    sed -i '/imports = \[/a\    ./disko.nix' "$TMP_HW"
  fi

  # Garantir fileSystems."/persist".neededForBoot = true
  if ! grep -q 'neededForBoot' "$TMP_HW"; then
    echo '  fileSystems."/persist".neededForBoot = true;' >> "$TMP_HW"
  fi

  # Garantir zramSwap (copiar do template original se necessário)
  if ! grep -q 'zramSwap' "$TMP_HW" && grep -q 'zramSwap' "$HW_FILE"; then
    grep -A5 'zramSwap' "$HW_FILE" >> "$TMP_HW"
  fi

  sudo cp "$TMP_HW" "$HW_FILE"
  success "hardware-configuration.nix atualizado com a configuração real do hardware."
fi

# ---------------------------------------------------------------------------
# 5. Criar arquivo de usuário
# ---------------------------------------------------------------------------

echo
info "==> Passo 5: Criar arquivo de usuário"

ask OPT_USER "Nome de usuário (login)"
[[ -n "$OPT_USER" ]] || die "Nome de usuário é obrigatório."

# Validar nome de usuário POSIX
if ! [[ "$OPT_USER" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
  die "Nome de usuário inválido: '$OPT_USER'. Use apenas letras minúsculas, números, hifens e underscores."
fi

USER="$OPT_USER"
USER_FILE="$CONFIG_DIR/users/$USER.nix"

ask OPT_FULL_NAME "Nome completo do usuário" "$USER"
FULL_NAME="${OPT_FULL_NAME:-$USER}"

if [[ -f "$USER_FILE" ]]; then
  warn "Arquivo $USER_FILE já existe."
  if ! confirm "Sobrescrever?"; then
    info "Mantendo arquivo existente."
  else
    cp "$CONFIG_DIR/users/skeleton.nix" "$USER_FILE"
    # Substituir "skeleton" pelo nome real e a descrição pelo nome completo
    sed -i \
      -e "s|users\.users\.skeleton|users.users.$USER|g" \
      -e "s|users\.skeleton\b|users.$USER|g" \
      -e "s|home-manager\.users\.skeleton|home-manager.users.$USER|g" \
      -e "s|Nome Completo do Usuário|$FULL_NAME|g" \
      "$USER_FILE"
    success "Arquivo de usuário $USER_FILE criado."
  fi
else
  cp "$CONFIG_DIR/users/skeleton.nix" "$USER_FILE"
  sed -i \
    -e "s|users\.users\.skeleton|users.users.$USER|g" \
    -e "s|users\.skeleton\b|users.$USER|g" \
    -e "s|home-manager\.users\.skeleton|home-manager.users.$USER|g" \
    -e "s|Nome Completo do Usuário|$FULL_NAME|g" \
    "$USER_FILE"
  success "Arquivo de usuário $USER_FILE criado."
fi

# ---------------------------------------------------------------------------
# 6. Adicionar arquivo de usuário ao índice do git (ESSENCIAL)
# ---------------------------------------------------------------------------

echo
info "==> Passo 6: Registrar arquivo de usuário no índice do git"

# O Nix avalia flakes a partir do índice do git.
# Arquivos gitignored que não estejam no índice são invisíveis ao Nix,
# causando erros "module not found" no nixos-install.
# git add --force adiciona ao índice sem fazer commit.
git add --force "$USER_FILE"
success "Arquivo $USER_FILE adicionado ao índice do git (sem commit)."

# ---------------------------------------------------------------------------
# 7. Atualizar configuration.nix com o import do usuário
# ---------------------------------------------------------------------------

echo
info "==> Passo 7: Configurar importação do usuário em $CFG_FILE"

USER_IMPORT="./../../users/$USER.nix"

if grep -qF "$USER_IMPORT" "$CFG_FILE"; then
  info "Import de $USER.nix já presente em $CFG_FILE."
else
  # Substituir o placeholder comentado, se existir
  if grep -q 'seu-usuario\.nix\|<seu-usuario>' "$CFG_FILE"; then
    sed -i "s|# .*seu-usuario\.nix.*|$USER_IMPORT|g" "$CFG_FILE"
    success "Placeholder substituído pelo import de $USER.nix."
  elif grep -q "# Carregar configurações de usuário" "$CFG_FILE"; then
    # Inserir após o comentário de usuários
    sed -i "/# Carregar configurações de usuário/a\\    $USER_IMPORT" "$CFG_FILE"
    success "Import de $USER.nix adicionado após comentário de usuários."
  else
    # Inserir no final dos imports
    sed -i "/^  \];$/i\\    $USER_IMPORT" "$CFG_FILE"
    success "Import de $USER.nix adicionado aos imports."
  fi
fi

# Garantir que configuration.nix também está no índice (pode ter sido editado)
git add "$CFG_FILE" "$HW_FILE" "$DISKO_FILE"
success "Arquivos de configuração registrados no índice do git."

# ---------------------------------------------------------------------------
# 8. Instalar o NixOS
# ---------------------------------------------------------------------------

echo
info "==> Passo 8: Instalar o NixOS"

# Copiar a configuração para /mnt (o nixos-install aceitará o caminho local,
# mas é mais seguro copiar para garantir que /mnt/etc/nixos tenha os arquivos)
if confirm "Copiar configuração para /mnt/etc/nixos e executar nixos-install?"; then
  sudo mkdir -p /mnt/etc
  # rsync é preferível mas pode não estar disponível; usar cp com fallback
  if command -v rsync >/dev/null 2>&1; then
    sudo rsync -a --delete "$CONFIG_DIR/" /mnt/etc/nixos/
  else
    sudo cp -r "$CONFIG_DIR" /mnt/etc/nixos
  fi
  success "Configuração copiada para /mnt/etc/nixos."

  info "Executando nixos-install..."
  sudo nixos-install --flake "/mnt/etc/nixos#$HOST"
  success "NixOS instalado com sucesso!"
else
  warn "Instalação pulada. Execute manualmente:"
  echo "  sudo cp -r $CONFIG_DIR /mnt/etc/nixos"
  echo "  sudo nixos-install --flake /mnt/etc/nixos#$HOST"
fi

# ---------------------------------------------------------------------------
# 9. Definir senhas
# ---------------------------------------------------------------------------

echo
info "==> Passo 9: Definir senhas"

if confirm "Definir senha para o usuário '$USER' agora (via nixos-enter)?"; then
  info "Entrando no sistema instalado para definir a senha de '$USER'..."
  sudo nixos-enter --root /mnt -- passwd "$USER"
  success "Senha do usuário '$USER' definida."
fi

if confirm "Definir senha do root também?"; then
  sudo nixos-enter --root /mnt -- passwd root
  success "Senha do root definida."
fi

# ---------------------------------------------------------------------------
# 10. Finalizar
# ---------------------------------------------------------------------------

echo
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}${BOLD}║               Instalação concluída com sucesso!              ║${RESET}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
echo
echo -e "  Para finalizar, desmonte e reinicie:"
echo -e "    ${CYAN}sudo umount -R /mnt${RESET}"
echo -e "    ${CYAN}sudo reboot${RESET}"
echo
echo -e "  Após o primeiro boot, consulte ${BOLD}INSTALLATION.md${RESET} para:"
echo -e "    • Configurar Flatpaks"
echo -e "    • Instalar Homebrew (opcional)"
echo -e "    • Configurar Secure Boot com lanzaboote (apenas barbudus)"
echo -e "    • Configurar desbloqueio automático LUKS via TPM2"
echo
