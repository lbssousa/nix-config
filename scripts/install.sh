#!/usr/bin/env bash
# install.sh — Script de instalação automática do NixOS
#
# Automatiza os passos descritos em INSTALLATION.md:
#   1. Habilita Flakes no ambiente live
#   2. Seleciona o host e o disco de destino
#   3. Particiona e formata o disco com disko
#   4. Gera o hostId ZFS e atualiza hardware-configuration.nix
#   5. Cria arquivos de usuário a partir do skeleton
#   6. Adiciona os arquivos de usuário ao índice do git (git add --force)
#   7. Atualiza configuration.nix com os imports dos usuários
#   8. Instala o NixOS
#   9. Define senhas via nixos-enter
#
# Uso:
#   bash scripts/install.sh [--host <hostname>] [--disk <device>]
#                           [--user "login:Nome Completo:sudo"]
#                           [--user "login2:Nome2:nosudo"] ...
#                           [--non-interactive]
#                           [--help]
#
# Opções:
#   --host            Nome do host NixOS (ex: barbudus, bigodon)
#   --disk            Dispositivo de disco (ex: /dev/nvme0n1, /dev/sda)
#   --user            Usuário no formato "login:Nome Completo:sudo|nosudo".
#                     Pode ser repetido para criar múltiplos usuários.
#                     "sudo" (padrão) inclui o usuário no grupo wheel (sudo).
#                     "nosudo" cria o usuário sem permissão de sudo.
#   --non-interactive Não faz perguntas; falha se informações obrigatórias
#                     não forem fornecidas via flags
#   --help, -h        Exibe ajuda e sai

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
# Constantes de cache binário
# ---------------------------------------------------------------------------
# O cache da nix-community disponibiliza artefatos pré-compilados do lanzaboote
# (e outros pacotes), evitando que o nixos-install precise compilar dependências
# Rust do zero e fazer downloads do crates.io (que podem falhar com erro 500).
NIX_COMMUNITY_SUBSTITUTER="https://nix-community.cachix.org"
NIX_COMMUNITY_KEY="nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCUSeBs="

# ---------------------------------------------------------------------------
# Argumento parsing
# ---------------------------------------------------------------------------

OPT_HOST=""
OPT_DISK=""
OPT_USERS_LOGIN=()
OPT_USERS_FULLNAME=()
OPT_USERS_SUDO=()
OPT_NON_INTERACTIVE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)           OPT_HOST="$2";          shift 2 ;;
    --disk)           OPT_DISK="$2";          shift 2 ;;
    --user)
      # Formato: "login:Nome Completo:sudo|nosudo"
      # O terceiro campo é opcional (padrão: sudo).
      _spec="$2"
      _login="${_spec%%:*}"
      _after_login="${_spec#*:}"
      if [[ "$_after_login" == "$_spec" ]]; then
        # Apenas login, sem separadores
        _fname=""
        _sudo_flag="true"
      else
        _last_field="${_after_login##*:}"
        if [[ "$_last_field" == "nosudo" || "$_last_field" == "false" || "$_last_field" == "no" ]]; then
          _sudo_flag="false"
          _fname="${_after_login%:*}"
        else
          _sudo_flag="true"
          _fname="$_after_login"
        fi
      fi
      OPT_USERS_LOGIN+=("$_login")
      OPT_USERS_FULLNAME+=("$_fname")
      OPT_USERS_SUDO+=("$_sudo_flag")
      shift 2 ;;
    --non-interactive) OPT_NON_INTERACTIVE=true; shift ;;
    --help|-h)
      cat <<'EOF'
Uso:
  bash scripts/install.sh [--host <hostname>] [--disk <device>]
                          [--user "login:Nome Completo:sudo"]
                          [--user "login2:Nome2:nosudo"] ...
                          [--non-interactive] [--help]

Opções:
  --host            Nome do host NixOS (ex: barbudus, bigodon).
                    Se omitido, é perguntado interativamente.
  --disk            Dispositivo de disco de destino (ex: /dev/nvme0n1, /dev/sda).
                    Se omitido, é perguntado interativamente.
  --user            Usuário no formato "login:Nome Completo:sudo|nosudo".
                    Pode ser repetido para criar múltiplos usuários.
                    "sudo" (padrão) inclui o usuário no grupo wheel (sudo).
                    "nosudo" cria o usuário sem permissão de sudo.
                    Se omitido, é perguntado interativamente.
  --non-interactive Não faz perguntas; falha se informações obrigatórias
                    não forem fornecidas via flags.
  --help, -h        Exibe esta ajuda e sai.

Exemplos:
  # Instalação totalmente interativa (recomendado para iniciantes):
  bash scripts/install.sh

  # Instalação não-interativa:
  bash scripts/install.sh \
    --host barbudus \
    --disk /dev/nvme0n1 \
    --user "joao:João Silva:sudo" \
    --user "maria:Maria Souza:nosudo" \
    --non-interactive

Este script automatiza os passos descritos em INSTALLATION.md:
  1. Habilita Flakes no ambiente live
  2. Seleciona o host e o disco de destino
  3. Particiona e formata o disco com disko
  4. Gera o hostId ZFS e atualiza hardware-configuration.nix
  5. Cria arquivos de usuário a partir do skeleton
  6. Adiciona os arquivos de usuário ao índice do git (git add --force)
  7. Atualiza configuration.nix com os imports dos usuários
  8. Instala o NixOS
  9. Define senhas via nixos-enter
EOF
      exit 0 ;;
    *) die "Opção desconhecida: $1. Use --help para ver as opções disponíveis." ;;
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
# Escreve na configuração do usuário atual
NIX_CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nix"
mkdir -p "$NIX_CONF_DIR"
if ! grep -q "experimental-features" "$NIX_CONF_DIR/nix.conf" 2>/dev/null; then
  echo "experimental-features = nix-command flakes" >> "$NIX_CONF_DIR/nix.conf"
  success "Flakes habilitados em $NIX_CONF_DIR/nix.conf"
else
  info "Flakes já estão habilitados (usuário atual)."
fi
# Adicionar o cache nix-community ao nix.conf do usuário atual (idempotente)
if ! grep -qF "$NIX_COMMUNITY_KEY" "$NIX_CONF_DIR/nix.conf" 2>/dev/null; then
  {
    echo "extra-substituters = $NIX_COMMUNITY_SUBSTITUTER"
    echo "extra-trusted-public-keys = $NIX_COMMUNITY_KEY"
  } >> "$NIX_CONF_DIR/nix.conf"
  success "Cache nix-community adicionado em $NIX_CONF_DIR/nix.conf"
fi

# Garantir que o root também leia as features experimentais e o cache binário.
# Comandos executados com sudo (ex: nixos-install, nix run) usam o ambiente
# do root e não herdam o nix.conf do usuário atual.
# Tentamos /etc/nix/nix.conf primeiro (lido globalmente), mas no Live CD do NixOS
# esse diretório é somente leitura. Nesse caso, usamos /root/.config/nix/nix.conf.
ROOT_NIX_CONF="/etc/nix/nix.conf"
ROOT_USER_NIX_CONF="/root/.config/nix/nix.conf"

if sudo grep -q "experimental-features" "$ROOT_NIX_CONF" 2>/dev/null || \
   sudo grep -q "experimental-features" "$ROOT_USER_NIX_CONF" 2>/dev/null; then
  info "Flakes já estão habilitados para o root."
else
  # Tentar /etc/nix/nix.conf (pode ser read-only no Live CD)
  if sudo mkdir -p "$(dirname "$ROOT_NIX_CONF")" 2>/dev/null && \
     echo "experimental-features = nix-command flakes" | sudo tee -a "$ROOT_NIX_CONF" > /dev/null 2>&1; then
    success "Flakes habilitados em $ROOT_NIX_CONF (root/global)."
  else
    # Fallback: usar ~/.config/nix/nix.conf do root (gravável no Live CD via tmpfs)
    warn "/etc/nix é somente leitura (Live CD). Usando $ROOT_USER_NIX_CONF como fallback."
    sudo mkdir -p "$(dirname "$ROOT_USER_NIX_CONF")"
    echo "experimental-features = nix-command flakes" | sudo tee -a "$ROOT_USER_NIX_CONF" > /dev/null
    success "Flakes habilitados em $ROOT_USER_NIX_CONF (root, user-level)."
  fi
fi

# Adicionar o cache nix-community ao nix.conf do root (idempotente).
# Isso garante que 'nix run' (disko) e 'nixos-install' utilizem o cache.
# Tentamos primeiro /etc/nix/nix.conf; se somente leitura, usamos o user-level do root.
if ! sudo grep -qF "$NIX_COMMUNITY_KEY" "$ROOT_NIX_CONF" 2>/dev/null; then
  _nix_community_block() {
    printf 'extra-substituters = %s\nextra-trusted-public-keys = %s\n' \
      "$NIX_COMMUNITY_SUBSTITUTER" "$NIX_COMMUNITY_KEY"
  }
  if _nix_community_block | sudo tee -a "$ROOT_NIX_CONF" > /dev/null 2>&1; then
    success "Cache nix-community adicionado em $ROOT_NIX_CONF."
  else
    # /etc/nix/nix.conf é somente leitura — adicionar ao nix.conf user-level do root
    if ! sudo grep -qF "$NIX_COMMUNITY_KEY" "$ROOT_USER_NIX_CONF" 2>/dev/null; then
      sudo mkdir -p "$(dirname "$ROOT_USER_NIX_CONF")"
      _nix_community_block | sudo tee -a "$ROOT_USER_NIX_CONF" > /dev/null
      success "Cache nix-community adicionado em $ROOT_USER_NIX_CONF."
    else
      info "Cache nix-community já configurado em $ROOT_USER_NIX_CONF."
    fi
  fi
else
  info "Cache nix-community já configurado em $ROOT_NIX_CONF."
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
# Extrai o valor entre aspas após 'device = ' usando sed (mais portável que grep -P)
CURRENT_DISK=$(sed -n 's|.*device = "\([^"]*\)".*|\1|p' "$DISKO_FILE" | head -1)
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

info "Carregando módulo ZFS..."
sudo modprobe zfs || die "Falha ao carregar o módulo ZFS. Verifique se o kernel suporta ZFS (ex: nixos-enter ou use um Live CD com suporte a ZFS)."

info "Executando disko..."
sudo nix run github:nix-community/disko \
  --option extra-substituters "$NIX_COMMUNITY_SUBSTITUTER" \
  --option extra-trusted-public-keys "$NIX_COMMUNITY_KEY" \
  -- --mode disko "$DISKO_FILE"
success "Disco particionado e formatado com sucesso."

# ---------------------------------------------------------------------------
# 4. Gerar hostId ZFS e atualizar hardware-configuration.nix
# ---------------------------------------------------------------------------

echo
info "==> Passo 4: Configurar hostId ZFS"

HOST_ID=$(head -c 4 /dev/urandom | od -A n -t x1 | tr -d ' \n')
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

# O arquivo hardware-configuration.nix do repositório é mantido como fonte da verdade.
# Ele já contém todos os módulos, opções de swap, disko e sysctl corretos para o host.
# Apenas o networking.hostId é atualizado acima com um valor gerado aleatoriamente.
# Se necessário atualizar os módulos do kernel após a instalação, edite o arquivo
# hosts/<host>/hardware-configuration.nix diretamente e reaplique com nixos-rebuild.

# ---------------------------------------------------------------------------
# 5. Criar arquivos de usuário
# ---------------------------------------------------------------------------

echo
info "==> Passo 5: Criar contas de usuário"

USERS_LOGIN=()
USERS_FULLNAME=()
USERS_SUDO=()

_create_user_file() {
  local user="$1" full_name="$2" sudo_flag="$3"
  local user_file="$CONFIG_DIR/users/$user.nix"

  if [[ -f "$user_file" ]]; then
    warn "Arquivo $user_file já existe."
    if ! confirm "Sobrescrever?"; then
      info "Mantendo arquivo existente para $user."
      return
    fi
  fi

  cp "$CONFIG_DIR/users/skeleton.nix" "$user_file"
  sed -i \
    -e "s|users\.users\.skeleton|users.users.$user|g" \
    -e "s|users\.skeleton\b|users.$user|g" \
    -e "s|home-manager\.users\.skeleton|home-manager.users.$user|g" \
    -e "s|Nome Completo do Usuário|$full_name|g" \
    "$user_file"

  # Remover grupo wheel (sudo) se não solicitado
  if [[ "$sudo_flag" == "false" ]]; then
    sed -i '/# Remova "wheel" abaixo se o usuário NÃO deve ter permissão de sudo:/d' "$user_file"
    sed -i '/"wheel" # sudo/d' "$user_file"
  fi

  success "Arquivo de usuário $user_file criado (sudo: $sudo_flag)."
}

if [[ "$OPT_NON_INTERACTIVE" == "true" ]]; then
  [[ ${#OPT_USERS_LOGIN[@]} -gt 0 ]] || die "Modo não-interativo: nenhum usuário definido. Use --user 'login:Nome:sudo'."
  USERS_LOGIN=("${OPT_USERS_LOGIN[@]}")
  USERS_FULLNAME=("${OPT_USERS_FULLNAME[@]}")
  USERS_SUDO=("${OPT_USERS_SUDO[@]}")
else
  # Pré-popular com usuários passados via flags
  USERS_LOGIN=("${OPT_USERS_LOGIN[@]}")
  USERS_FULLNAME=("${OPT_USERS_FULLNAME[@]}")
  USERS_SUDO=("${OPT_USERS_SUDO[@]}")

  # Loop interativo para adicionar usuários
  while true; do
    if [[ ${#USERS_LOGIN[@]} -gt 0 ]]; then
      echo
      echo "Usuários definidos:"
      for _i in "${!USERS_LOGIN[@]}"; do
        _sudo_label="com sudo"
        [[ "${USERS_SUDO[$_i]}" == "false" ]] && _sudo_label="sem sudo"
        echo "  $((_i + 1)). ${USERS_LOGIN[$_i]} (${USERS_FULLNAME[$_i]:-}) — $_sudo_label"
      done
      if ! confirm "Adicionar outro usuário?"; then
        break
      fi
    fi

    echo -ne "${BOLD}Nome de usuário (login): ${RESET}"
    read -r _tmp_login
    if [[ -z "$_tmp_login" ]]; then
      warn "Nome de usuário vazio, tente novamente."
      continue
    fi
    if ! [[ "$_tmp_login" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
      error "Nome de usuário inválido: '$_tmp_login'. Use apenas letras minúsculas, números, hifens e underscores."
      continue
    fi

    echo -ne "${BOLD}Nome completo [$_tmp_login]: ${RESET}"
    read -r _tmp_fname
    [[ -z "$_tmp_fname" ]] && _tmp_fname="$_tmp_login"

    echo -ne "${BOLD}Conceder permissão sudo (wheel)? [S/n]: ${RESET}"
    read -r _tmp_sudo_resp
    _tmp_sudo="true"
    [[ "$_tmp_sudo_resp" =~ ^[nN]$ ]] && _tmp_sudo="false"

    USERS_LOGIN+=("$_tmp_login")
    USERS_FULLNAME+=("$_tmp_fname")
    USERS_SUDO+=("$_tmp_sudo")
  done

  [[ ${#USERS_LOGIN[@]} -gt 0 ]] || die "Pelo menos um usuário deve ser definido."
fi

for _i in "${!USERS_LOGIN[@]}"; do
  _create_user_file "${USERS_LOGIN[$_i]}" "${USERS_FULLNAME[$_i]:-${USERS_LOGIN[$_i]}}" "${USERS_SUDO[$_i]:-true}"
done

# ---------------------------------------------------------------------------
# 6. Adicionar arquivos de usuário ao índice do git (ESSENCIAL)
# ---------------------------------------------------------------------------

echo
info "==> Passo 6: Registrar arquivos de usuário no índice do git"

# O Nix avalia flakes a partir do índice do git.
# Arquivos gitignored que não estejam no índice são invisíveis ao Nix,
# causando erros "module not found" no nixos-install.
# git add --force adiciona ao índice sem fazer commit.
for _i in "${!USERS_LOGIN[@]}"; do
  _ufile="$CONFIG_DIR/users/${USERS_LOGIN[$_i]}.nix"
  git add --force "$_ufile"
  success "Arquivo $_ufile adicionado ao índice do git (sem commit)."
done

# ---------------------------------------------------------------------------
# 7. Atualizar configuration.nix com os imports dos usuários
# ---------------------------------------------------------------------------

echo
info "==> Passo 7: Configurar importações dos usuários em $CFG_FILE"

for _i in "${!USERS_LOGIN[@]}"; do
  _user="${USERS_LOGIN[$_i]}"
  USER_IMPORT="./../../users/$_user.nix"

  if grep -qF "$USER_IMPORT" "$CFG_FILE"; then
    info "Import de $_user.nix já presente em $CFG_FILE."
  else
    # Substituir o placeholder comentado, se existir (apenas para o primeiro usuário)
    if grep -q 'seu-usuario\.nix\|<seu-usuario>' "$CFG_FILE"; then
      sed -i "s|# .*seu-usuario\.nix.*|$USER_IMPORT|g" "$CFG_FILE"
      success "Placeholder substituído pelo import de $_user.nix."
    elif grep -q "# Carregar configurações de usuário" "$CFG_FILE"; then
      # Inserir após o comentário de usuários
      sed -i "/# Carregar configurações de usuário/a\\    $USER_IMPORT" "$CFG_FILE"
      success "Import de $_user.nix adicionado após comentário de usuários."
    else
      # Inserir no final dos imports
      sed -i "/^  \];$/i\\    $USER_IMPORT" "$CFG_FILE"
      success "Import de $_user.nix adicionado aos imports."
    fi
  fi
done

# Garantir que configuration.nix também está no índice (pode ter sido editado)
git add "$CFG_FILE" "$HW_FILE" "$DISKO_FILE"
success "Arquivos de configuração registrados no índice do git."

# ---------------------------------------------------------------------------
# 7a. Criar chaves Secure Boot (apenas para hosts com Lanzaboote)
# ---------------------------------------------------------------------------

echo
info "==> Passo 7a: Verificar suporte a Secure Boot (Lanzaboote)"

if grep -q 'boot\.lanzaboote' "$CFG_FILE" 2>/dev/null; then
  # Extrair o caminho do pkiBundle da configuração (ou usar padrão)
  _PKI_BUNDLE=$(sed -n 's/.*pkiBundle = "\([^"]*\)".*/\1/p' "$CFG_FILE" | head -1)
  _PKI_BUNDLE="${_PKI_BUNDLE:-/persist/etc/secureboot}"
  _SECUREBOOT_DIR="/mnt${_PKI_BUNDLE}"

  info "Host '$HOST' usa Lanzaboote (Secure Boot). pkiBundle: $_PKI_BUNDLE"

  if [ -f "${_SECUREBOOT_DIR}/GUID" ]; then
    info "Chaves Secure Boot já existem em ${_SECUREBOOT_DIR}."
  else
    info "Criando chaves PKI para Secure Boot em ${_SECUREBOOT_DIR}..."
    info "(Necessário para que o Lanzaboote instale o bootloader durante nixos-install)"
    sudo mkdir -p "${_SECUREBOOT_DIR}"
    sudo nix run \
      --option extra-substituters "$NIX_COMMUNITY_SUBSTITUTER" \
      --option extra-trusted-public-keys "$NIX_COMMUNITY_KEY" \
      nixpkgs#sbctl -- create-keys --database-path "${_SECUREBOOT_DIR}"
    success "Chaves Secure Boot criadas em ${_SECUREBOOT_DIR}."
    warn "As chaves ainda precisam ser registradas no firmware após o primeiro boot."
    warn "Consulte INSTALLATION.md → 'Configuração do Secure Boot' para os próximos passos."
  fi
else
  info "Host '$HOST' não usa Lanzaboote. Pulando criação de chaves Secure Boot."
fi

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
    # Copiar o conteúdo do diretório (não o diretório em si) para /mnt/etc/nixos/
    sudo cp -r "$CONFIG_DIR/." /mnt/etc/nixos/
  fi
  success "Configuração copiada para /mnt/etc/nixos."

  info "Executando nixos-install..."
  # Passa os caches binários explicitamente para que o nixos-install os use mesmo
  # que o nix.conf do live CD não os contenha. Isso evita compilações do zero
  # (ex: dependências Rust do lanzaboote) e downloads frágeis do crates.io.
  sudo nixos-install \
    --flake "/mnt/etc/nixos#$HOST" \
    --option accept-flake-config true \
    --option extra-substituters "$NIX_COMMUNITY_SUBSTITUTER" \
    --option extra-trusted-public-keys "$NIX_COMMUNITY_KEY"
  success "NixOS instalado com sucesso!"
else
  warn "Instalação pulada. Execute manualmente:"
  echo "  sudo cp -r $CONFIG_DIR /mnt/etc/nixos"
  echo "  sudo nixos-install --flake /mnt/etc/nixos#$HOST \\"
  echo "    --option accept-flake-config true \\"
  echo "    --option extra-substituters \"$NIX_COMMUNITY_SUBSTITUTER\" \\"
  echo "    --option extra-trusted-public-keys \"$NIX_COMMUNITY_KEY\""
fi

# ---------------------------------------------------------------------------
# 9. Definir senhas
# ---------------------------------------------------------------------------

echo
info "==> Passo 9: Definir senhas"
info "Com impermanência (ZFS rollback), /etc/shadow precisa ser salvo em"
info "/persist/etc/shadow para sobreviver ao rollback do primeiro boot."

_USERS_WITH_PASSWORD=()
# Padrão de nome de usuário seguro para uso em nomes de arquivo
_SAFE_USERNAME='^[a-z_][a-z0-9_-]*$'

if confirm "Definir senhas personalizadas para os usuários criados agora (via nixos-enter)?"; then
  for _i in "${!USERS_LOGIN[@]}"; do
    _user="${USERS_LOGIN[$_i]}"
    info "Definindo senha para '$_user'..."
    sudo nixos-enter --root /mnt -- passwd "$_user"
    success "Senha do usuário '$_user' definida."
    # Registrar apenas nomes de usuário com caracteres seguros para nomes de arquivo
    if [[ "$_user" =~ $_SAFE_USERNAME ]]; then
      _USERS_WITH_PASSWORD+=("$_user")
    fi
  done
else
  info "Senhas não definidas agora. No primeiro login, os usuários usarão a senha"
  info "temporária 'nixos' (via initialPassword) e serão solicitados a trocá-la."
fi

if confirm "Definir senha do root também?"; then
  sudo nixos-enter --root /mnt -- passwd root
  success "Senha do root definida."
fi

# Copiar /etc/shadow para /persist/etc/shadow para que as senhas sobrevivam
# ao rollback ZFS. Sem isso, as senhas são perdidas no primeiro reboot.
# Usar `install` para definir permissões 640 atomicamente (sem janela de acesso).
if [ -s /mnt/etc/shadow ]; then
  sudo mkdir -p /mnt/persist/etc
  sudo install -m 640 /mnt/etc/shadow /mnt/persist/etc/shadow
  success "/etc/shadow copiado para /persist/etc/shadow (persiste entre boots)."
else
  warn "/mnt/etc/shadow não encontrado ou vazio; pulando cópia para /persist."
fi

# Criar arquivos de flag para usuários que já definiram senha durante a instalação.
# Isso evita que o sistema force a troca de senha no primeiro login para esses usuários
# (a troca forçada via chage é para usuários com a senha temporária 'nixos').
for _user in "${_USERS_WITH_PASSWORD[@]}"; do
  sudo touch "/mnt/persist/.password-change-required-${_user}"
  info "Usuário '$_user': senha pré-definida — troca não será forçada no primeiro login."
done

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
