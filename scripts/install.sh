#!/usr/bin/env bash
# install.sh — Script de instalação automática do NixOS
#
# Automatiza os passos descritos em INSTALLATION.md:
#   1. Habilita Flakes no ambiente live
#   2. Seleciona o host e o disco de destino
#   3. Particiona e formata o disco com disko
#   4. Cria arquivos de usuário a partir do skeleton
#   5. Adiciona os arquivos de usuário ao índice do git (git add --force)
#   6. Atualiza configuration.nix com os imports dos usuários
#   6a. Cria chaves Secure Boot (apenas hosts com Lanzaboote)
#   6b. Restaura chave age do sops-nix (opcional)
#   7. Instala o NixOS
#   8. Define senhas via nixos-enter
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
#   --age-keys-backup Caminho para o backup do arquivo keys.txt da chave age
#                     (sops-nix). Copiado para /persist/etc/sops/age/keys.txt
#                     no sistema instalado. Se omitido, é perguntado
#                     interativamente (pode ser deixado vazio para pular).
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
# Garantir execução como root
# ---------------------------------------------------------------------------

if [[ $EUID -ne 0 ]]; then
  info "Este script deve ser executado como root. Reexecutando com sudo..."
  exec sudo -E bash "${BASH_SOURCE[0]}" "$@"
fi

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
OPT_AGE_KEYS_BACKUP=""
OPT_NON_INTERACTIVE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)           OPT_HOST="$2";          shift 2 ;;
    --disk)           OPT_DISK="$2";          shift 2 ;;
    --age-keys-backup) OPT_AGE_KEYS_BACKUP="$2"; shift 2 ;;
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
  --age-keys-backup Caminho para o backup do arquivo keys.txt da chave age
                    (sops-nix). Copiado para /persist/etc/sops/age/keys.txt
                    no sistema instalado. Se omitido, é perguntado
                    interativamente (pode ser deixado vazio para pular).
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
    --user "joao:cavalo:sudo" \
    --user "maria:macaco:nosudo" \
    --non-interactive

Este script automatiza os passos descritos em INSTALLATION.md:
  1. Habilita Flakes no ambiente live
  2. Seleciona o host e o disco de destino
  3. Particiona e formata o disco com disko
  4. Cria arquivos de usuário a partir do skeleton
  5. Adiciona os arquivos de usuário ao índice do git (git add --force)
  6. Atualiza configuration.nix com os imports dos usuários
  6a. Cria chaves Secure Boot (apenas hosts com Lanzaboote)
  6b. Restaura chave age do sops-nix (opcional)
  7. Instala o NixOS
  8. Define senhas via nixos-enter
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

# Habilitar Flakes e cache nix-community para o root (idempotente).
# O script já roda como root; tentamos /etc/nix/nix.conf (global) e usamos
# /root/.config/nix/nix.conf como fallback quando /etc/nix é somente leitura
# (caso típico do Live CD do NixOS).
NIX_CONF_GLOBAL="/etc/nix/nix.conf"
NIX_CONF_USER="/root/.config/nix/nix.conf"

_nix_community_block() {
  printf 'extra-substituters = %s\nextra-trusted-public-keys = %s\n' \
    "$NIX_COMMUNITY_SUBSTITUTER" "$NIX_COMMUNITY_KEY"
}

_configure_nix_conf() {
  local conf="$1"

  if ! grep -q "experimental-features" "$conf" 2>/dev/null; then
    echo "experimental-features = nix-command flakes" >> "$conf"
    success "Flakes habilitados em $conf"
  else
    info "Flakes já estão habilitados em $conf."
  fi

  if ! grep -qF "$NIX_COMMUNITY_KEY" "$conf" 2>/dev/null; then
    _nix_community_block >> "$conf"
    success "Cache nix-community adicionado em $conf."
  else
    info "Cache nix-community já configurado em $conf."
  fi
}

if mkdir -p "$(dirname "$NIX_CONF_GLOBAL")" 2>/dev/null && \
   { [[ -w "$NIX_CONF_GLOBAL" ]] || { [[ ! -e "$NIX_CONF_GLOBAL" ]] && [[ -w "$(dirname "$NIX_CONF_GLOBAL")" ]]; }; }; then
  _configure_nix_conf "$NIX_CONF_GLOBAL"
else
  warn "/etc/nix é somente leitura (Live CD). Usando $NIX_CONF_USER como fallback."
  mkdir -p "$(dirname "$NIX_CONF_USER")"
  _configure_nix_conf "$NIX_CONF_USER"
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
if [[ "$OPT_NON_INTERACTIVE" != "true" ]] && ! confirm "Continuar com a formatação de $DISK?"; then
  die "Formatação cancelada pelo usuário."
fi

info "Executando disko..."
nix run github:nix-community/disko \
  --option extra-substituters "$NIX_COMMUNITY_SUBSTITUTER" \
  --option extra-trusted-public-keys "$NIX_COMMUNITY_KEY" \
  -- --mode disko "$DISKO_FILE"
success "Disco particionado e formatado com sucesso."

# ---------------------------------------------------------------------------
# 4. Criar arquivos de usuário
# ---------------------------------------------------------------------------

echo
info "==> Passo 4: Criar contas de usuário"

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
# 5. Adicionar arquivos de usuário ao índice do git (ESSENCIAL)
# ---------------------------------------------------------------------------

echo
info "==> Passo 5: Registrar arquivos de usuário no índice do git"

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
# 6. Atualizar configuration.nix com os imports dos usuários
# ---------------------------------------------------------------------------

echo
info "==> Passo 6: Configurar importações dos usuários em $CFG_FILE"

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

# Garantir que configuration.nix e disko.nix também estão no índice (podem ter sido editados)
git add "$CFG_FILE" "$DISKO_FILE"
success "Arquivos de configuração registrados no índice do git."

# ---------------------------------------------------------------------------
# 6a. Criar chaves Secure Boot (apenas para hosts com Lanzaboote)
# ---------------------------------------------------------------------------

echo
info "==> Passo 6a: Verificar suporte a Secure Boot (Lanzaboote)"

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
    # Por que --disable-landlock é necessário:
    #   O sbctl ativa o sandbox Landlock (LSM do Linux) antes de processar as
    #   flags --export e --database-path. O Landlock é configurado com base no
    #   caminho padrão /var/lib/sbctl, bloqueando acesso a qualquer outro path —
    #   inclusive para root (é uma restrição do processo, não do usuário).
    #   Sem --disable-landlock, qualquer acesso a ${_SECUREBOOT_DIR} resulta em
    #   EACCES, que o sbctl reporta como "sbctl requires root to run: open ...".
    #
    # Por que --export e --database-path separados:
    #   --database-path define apenas o caminho do ARQUIVO GUID (não o diretório).
    #   --export define o diretório de chaves (keydir).
    #   Juntos criam a estrutura esperada pelo Lanzaboote em pkiBundle:
    #     ${_SECUREBOOT_DIR}/GUID
    #     ${_SECUREBOOT_DIR}/keys/PK/{PK.key,PK.pem}
    #     ${_SECUREBOOT_DIR}/keys/KEK/{KEK.key,KEK.pem}
    #     ${_SECUREBOOT_DIR}/keys/db/{db.key,db.pem}
    mkdir -p "${_SECUREBOOT_DIR}"
    nix run \
      --option extra-substituters "$NIX_COMMUNITY_SUBSTITUTER" \
      --option extra-trusted-public-keys "$NIX_COMMUNITY_KEY" \
      nixpkgs#sbctl -- --disable-landlock create-keys \
      --export "${_SECUREBOOT_DIR}/keys" \
      --database-path "${_SECUREBOOT_DIR}/GUID"
    success "Chaves Secure Boot criadas em ${_SECUREBOOT_DIR}."
    warn "As chaves ainda precisam ser registradas no firmware após o primeiro boot."
    warn "Consulte INSTALLATION.md → 'Configuração do Secure Boot' para os próximos passos."
  fi
else
  info "Host '$HOST' não usa Lanzaboote. Pulando criação de chaves Secure Boot."
fi

# ---------------------------------------------------------------------------
# 6b. Restaurar chave age do sops-nix (opcional)
# ---------------------------------------------------------------------------

echo
info "==> Passo 6b: Restaurar chave age do sops-nix"

_AGE_KEYS_DST="/mnt/persist/etc/sops/age/keys.txt"

if [[ "$OPT_NON_INTERACTIVE" != "true" && -z "$OPT_AGE_KEYS_BACKUP" ]]; then
  info "Se você usa sops-nix com secrets de sistema, copie aqui o backup de"
  info "keys.txt para /persist/etc/sops/age/keys.txt no sistema instalado."
  echo -ne "${BOLD}Caminho para o backup de keys.txt (Enter para pular): ${RESET}"
  read -r OPT_AGE_KEYS_BACKUP
fi

if [[ -n "$OPT_AGE_KEYS_BACKUP" ]]; then
  # Rejeitar caminhos com caracteres nulos ou quebras de linha
  if [[ "$OPT_AGE_KEYS_BACKUP" == *$'\n'* || "$OPT_AGE_KEYS_BACKUP" == *$'\0'* ]]; then
    die "Caminho inválido para o backup de keys.txt."
  fi
  if [[ ! -f "$OPT_AGE_KEYS_BACKUP" ]]; then
    die "Arquivo de backup '$OPT_AGE_KEYS_BACKUP' não encontrado."
  fi
  mkdir -p "$(dirname "$_AGE_KEYS_DST")"
  install -m 600 "$OPT_AGE_KEYS_BACKUP" "$_AGE_KEYS_DST"
  success "Chave age copiada para $_AGE_KEYS_DST."
else
  info "Nenhum backup de keys.txt fornecido. Pulando."
fi

# ---------------------------------------------------------------------------
# 7. Instalar o NixOS
# ---------------------------------------------------------------------------

echo
info "==> Passo 7: Instalar o NixOS"

# Copiar a configuração para /mnt (o nixos-install aceitará o caminho local,
# mas é mais seguro copiar para garantir que /mnt/etc/nixos tenha os arquivos)
if [[ "$OPT_NON_INTERACTIVE" == "true" ]] || confirm "Copiar configuração para /mnt/etc/nixos e executar nixos-install?"; then
  mkdir -p /mnt/etc
  # rsync é preferível mas pode não estar disponível; usar cp com fallback
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete "$CONFIG_DIR/" /mnt/etc/nixos/
  else
    # Copiar o conteúdo do diretório (não o diretório em si) para /mnt/etc/nixos/
    cp -r "$CONFIG_DIR/." /mnt/etc/nixos/
  fi
  success "Configuração copiada para /mnt/etc/nixos."

  info "Executando nixos-install..."
  # Passa os caches binários explicitamente para que o nixos-install os use mesmo
  # que o nix.conf do live CD não os contenha. Isso evita compilações do zero
  # (ex: dependências Rust do lanzaboote) e downloads frágeis do crates.io.
  nixos-install \
    --flake "/mnt/etc/nixos#$HOST" \
    --option accept-flake-config true \
    --option extra-substituters "$NIX_COMMUNITY_SUBSTITUTER" \
    --option extra-trusted-public-keys "$NIX_COMMUNITY_KEY"
  success "NixOS instalado com sucesso!"

  # -----------------------------------------------------------------------
  # 7b. Pré-configurar repositório Flathub no sistema instalado
  # -----------------------------------------------------------------------
  # Executado via nixos-enter para que o repositório Flathub já esteja
  # disponível no primeiro boot, mesmo que a rede não esteja pronta antes
  # do serviço install-system-flatpaks. Os Flatpaks em si são instalados
  # automaticamente pelo serviço systemd install-system-flatpaks.
  echo
  info "==> Passo 7b: Pré-configurar repositório Flathub"
  if nixos-enter --root /mnt -- flatpak remote-add --system --if-not-exists flathub \
      https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null; then
    success "Repositório Flathub configurado no sistema instalado."
  else
    warn "Não foi possível pré-configurar o Flathub (sem internet?)."
    warn "O serviço install-system-flatpaks tentará novamente no primeiro boot."
  fi

  # -----------------------------------------------------------------------
  # 7c. Copiar conexões Wi-Fi do live CD para o sistema instalado
  # -----------------------------------------------------------------------
  # O diretório /etc/NetworkManager/system-connections já está declarado em
  # modules/system/core/impermanence.nix para ser persistido via bind mount de
  # /persist/etc/NetworkManager/system-connections. Ao copiar os perfis aqui,
  # eles estarão disponíveis imediatamente no primeiro boot — sem precisar
  # redigitar o SSID e a senha.
  # Permissões 600 são obrigatórias: o NetworkManager ignora/recusa perfis com
  # permissões mais abertas.
  echo
  info "==> Passo 7c: Copiar conexões Wi-Fi para o sistema instalado"
  _NM_SRC="/etc/NetworkManager/system-connections"
  _NM_DST="/mnt/persist/etc/NetworkManager/system-connections"
  _nm_copied=0
  if [[ -d "$_NM_SRC" ]]; then
    while IFS= read -r -d '' _profile; do
      mkdir -p "$_NM_DST"
      install -m 600 "$_profile" "$_NM_DST/"
      ((_nm_copied++)) || true
    done < <(find "$_NM_SRC" -maxdepth 1 -type f -print0)
  fi
  if ((_nm_copied > 0)); then
    success "$_nm_copied conexão(ões) Wi-Fi copiada(s) para $_NM_DST."
  else
    info "Nenhuma conexão Wi-Fi encontrada no live CD. Pulando."
  fi
else
  warn "Instalação pulada. Execute manualmente:"
  echo "  cp -r $CONFIG_DIR /mnt/etc/nixos"
  echo "  nixos-install --flake /mnt/etc/nixos#$HOST \\"
  echo "    --option accept-flake-config true \\"
  echo "    --option extra-substituters \"$NIX_COMMUNITY_SUBSTITUTER\" \\"
  echo "    --option extra-trusted-public-keys \"$NIX_COMMUNITY_KEY\""
fi

# ---------------------------------------------------------------------------
# 8. Definir senhas
# ---------------------------------------------------------------------------

echo
info "==> Passo 8: Definir senhas"
info "Com impermanência (tmpfs na raiz), /etc/shadow precisa ser salvo em"
info "/persist/etc/shadow para sobreviver ao próximo boot."

_USERS_WITH_PASSWORD=()
# Padrão de nome de usuário seguro para uso em nomes de arquivo
_SAFE_USERNAME='^[a-z_][a-z0-9_-]*$'

if confirm "Definir senhas personalizadas para os usuários criados agora (via nixos-enter)?"; then
  for _i in "${!USERS_LOGIN[@]}"; do
    _user="${USERS_LOGIN[$_i]}"
    info "Definindo senha para '$_user'..."
    nixos-enter --root /mnt -- passwd "$_user"
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
  nixos-enter --root /mnt -- passwd root
  success "Senha do root definida."
fi

# Copiar /etc/shadow para /persist/etc/shadow para que as senhas sobrevivam
# ao boot (a raiz tmpfs é reiniciada a cada boot, /persist é preservado via Btrfs).
# Usar `install` para definir permissões 640 atomicamente (sem janela de acesso).
if [ -s /mnt/etc/shadow ]; then
  mkdir -p /mnt/persist/etc
  install -m 640 /mnt/etc/shadow /mnt/persist/etc/shadow
  success "/etc/shadow copiado para /persist/etc/shadow (persiste entre boots)."
else
  warn "/mnt/etc/shadow não encontrado ou vazio; pulando cópia para /persist."
fi

# Criar arquivos de flag para usuários que já definiram senha durante a instalação.
# Isso evita que o sistema force a troca de senha no primeiro login para esses usuários
# (a troca forçada via chage é para usuários com a senha temporária 'nixos').
for _user in "${_USERS_WITH_PASSWORD[@]}"; do
  touch "/mnt/persist/.password-change-required-${_user}"
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
echo -e "  Após o primeiro boot:"
echo -e "    • Os Flatpaks são instalados automaticamente pelo serviço ${CYAN}install-system-flatpaks${RESET}"
echo -e "      (requer conexão com a internet no primeiro boot)"
echo -e "    • O Homebrew é instalado automaticamente pelo serviço ${CYAN}install-homebrew${RESET}"
echo -e "      (requer conexão com a internet no primeiro boot)"
echo -e "    • Configurar Secure Boot com lanzaboote (apenas barbudus)"
echo -e "      (consulte ${BOLD}INSTALLATION.md${RESET} → 'Configuração do Secure Boot')"
echo -e "    • Configurar desbloqueio automático LUKS via TPM2"
echo
