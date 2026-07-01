#!/usr/bin/env bash
# rename-user.sh — Renomeia um usuário NixOS neste repositório de configuração
#
# Automatiza:
#   1. Renomeia a conta do sistema (usermod / groupmod)
#   2. Move o diretório home (/home/<antigo> → /home/<novo>)
#   3. Renomeia e atualiza os arquivos Nix (users/,
#      dendritic/flake/home-configurations.nix)
#   4. Atualiza arquivos persistidos em /persist (flags de senha, u2f-mappings)
#   5. Encena todas as alterações no git
#   6. Oferece executar 'nixos-rebuild switch' ao final
#
# Uso:
#   sudo bash scripts/rename-user.sh <nome-antigo> <nome-novo>
#
# Pré-condições:
#   - Executar como root
#   - O usuário antigo não pode estar com sessão ativa
#   - O nome novo não pode estar em uso no sistema
#   - Executar a partir do diretório do repositório NixOS (/etc/nixos)
#
# Após o script:
#   - Se o usuário tiver chaves sops (secrets/*.yaml), renomeie-as manualmente:
#       sops secrets/<arquivo>.yaml
#   - Execute home-manager switch para o novo nome de usuário:
#       home-manager switch --flake /etc/nixos#<novo>@<host>

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Utilitários de saída
# ─────────────────────────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${BLUE}==>${NC} ${BOLD}$*${NC}"; }
success() { echo -e "${GREEN}  ✓${NC} $*"; }
warn()    { echo -e "${YELLOW}  ⚠${NC}  $*"; }
error()   { echo -e "${RED}  ✗${NC} $*" >&2; }
die()     { error "$*"; exit 1; }

confirm() {
    local msg="$1"
    local reply
    echo -en "${YELLOW}  ?${NC} ${msg} [s/N] "
    read -r reply
    [[ "${reply,,}" == "s" || "${reply,,}" == "sim" ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# Argumentos e verificações iniciais
# ─────────────────────────────────────────────────────────────────────────────

[[ $EUID -eq 0 ]] || die "Execute como root: sudo bash $0 ${*:-<antigo> <novo>}"

if [[ $# -ne 2 ]]; then
    echo "Uso: sudo bash $0 <nome-antigo> <nome-novo>"
    echo
    echo "Exemplo: sudo bash $0 laercio abutre"
    exit 1
fi

OLD_NAME="$1"
NEW_NAME="$2"

[[ "$OLD_NAME" =~ ^[a-z][a-z0-9_-]*$ ]] || die "Nome inválido: '$OLD_NAME'"
[[ "$NEW_NAME" =~ ^[a-z][a-z0-9_-]*$ ]] || die "Nome inválido: '$NEW_NAME'"
[[ "$OLD_NAME" != "$NEW_NAME" ]]          || die "Os nomes são idênticos."

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# Verificar que estamos no repositório NixOS correto
[[ -f "$REPO_ROOT/flake.nix" ]] || die "flake.nix não encontrado em '$REPO_ROOT'. Execute a partir do repositório NixOS."

# ─────────────────────────────────────────────────────────────────────────────
# Verificar pré-condições
# ─────────────────────────────────────────────────────────────────────────────

id "$OLD_NAME" &>/dev/null     || die "Usuário '$OLD_NAME' não existe no sistema."
! id "$NEW_NAME" &>/dev/null   || die "Usuário '$NEW_NAME' já existe no sistema."

# Alertar sobre sessão ativa
if who | awk '{print $1}' | grep -qx "$OLD_NAME"; then
    warn "O usuário '$OLD_NAME' está com sessão ativa."
    warn "Renomear um usuário com sessão aberta pode causar comportamento inesperado."
    echo
    confirm "Continuar mesmo assim?" || exit 1
    echo
fi

# ─────────────────────────────────────────────────────────────────────────────
# Resumo da operação
# ─────────────────────────────────────────────────────────────────────────────

echo
echo -e "  ${BOLD}Renomear usuário:${NC} ${RED}${OLD_NAME}${NC} → ${GREEN}${NEW_NAME}${NC}"
echo
echo    "  Sistema"
echo    "    • usermod -l / groupmod -n"
[[ -d "/home/$OLD_NAME" ]] && echo "    • /home/${OLD_NAME} → /home/${NEW_NAME}"
echo    "  Configuração Nix"
[[ -f "$REPO_ROOT/users/${OLD_NAME}.nix" ]] && \
    echo "    • users/${OLD_NAME}.nix → users/${NEW_NAME}.nix"
echo    "    • dendritic/flake/home-configurations.nix"
echo    "  /persist"
[[ -f "/persist/.password-change-required-${OLD_NAME}" ]] && \
    echo "    • .password-change-required-${OLD_NAME} → .password-change-required-${NEW_NAME}"
[[ -f "/persist/etc/u2f-mappings" ]] && grep -q "^${OLD_NAME}:" /persist/etc/u2f-mappings && \
    echo "    • u2f-mappings: entrada '${OLD_NAME}' atualizada"
echo

confirm "Confirmar renomeação?" || exit 1
echo

# ─────────────────────────────────────────────────────────────────────────────
# Passo 1 — Renomear conta do sistema
# ─────────────────────────────────────────────────────────────────────────────

info "Renomeando conta do sistema..."

usermod -l "$NEW_NAME" "$OLD_NAME"
success "Login renomeado: ${OLD_NAME} → ${NEW_NAME}"

if getent group "$OLD_NAME" &>/dev/null; then
    groupmod -n "$NEW_NAME" "$OLD_NAME"
    success "Grupo primário renomeado: ${OLD_NAME} → ${NEW_NAME}"
fi

# Mover diretório home
OLD_HOME="/home/$OLD_NAME"
NEW_HOME="/home/$NEW_NAME"

if [[ -d "$OLD_HOME" ]]; then
    usermod -d "$NEW_HOME" -m "$NEW_NAME"
    success "Home movido: ${OLD_HOME} → ${NEW_HOME}"
else
    usermod -d "$NEW_HOME" "$NEW_NAME"
    warn "Diretório ${OLD_HOME} não encontrado; campo home atualizado sem mover arquivos."
fi

# ─────────────────────────────────────────────────────────────────────────────
# Passo 2 — Atualizar arquivos em /persist
# ─────────────────────────────────────────────────────────────────────────────

info "Atualizando arquivos persistidos..."

OLD_FLAG="/persist/.password-change-required-${OLD_NAME}"
NEW_FLAG="/persist/.password-change-required-${NEW_NAME}"
if [[ -f "$OLD_FLAG" ]]; then
    mv "$OLD_FLAG" "$NEW_FLAG"
    success "Flag de senha: ${OLD_FLAG##*/} → ${NEW_FLAG##*/}"
fi

U2F_FILE="/persist/etc/u2f-mappings"
if [[ -f "$U2F_FILE" ]] && grep -q "^${OLD_NAME}:" "$U2F_FILE"; then
    sed -i "s/^${OLD_NAME}:/${NEW_NAME}:/" "$U2F_FILE"
    success "u2f-mappings: entrada '${OLD_NAME}' → '${NEW_NAME}'"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Passo 3 — Renomear e atualizar arquivos Nix
# ─────────────────────────────────────────────────────────────────────────────

info "Atualizando configuração Nix..."

# users/<old>.nix → users/<new>.nix
USER_FILE_OLD="$REPO_ROOT/users/${OLD_NAME}.nix"
USER_FILE_NEW="$REPO_ROOT/users/${NEW_NAME}.nix"
if [[ -f "$USER_FILE_OLD" ]]; then
    git mv "$USER_FILE_OLD" "$USER_FILE_NEW"
    sed -i "s/\"${OLD_NAME}\"/\"${NEW_NAME}\"/g" "$USER_FILE_NEW"
    git add "$USER_FILE_NEW"
    success "users/${OLD_NAME}.nix → users/${NEW_NAME}.nix"
else
    warn "Arquivo users/${OLD_NAME}.nix não encontrado; pulando."
fi

# dendritic/flake/home-configurations.nix (referências hardcoded ao nome)
HOME_CFG="$REPO_ROOT/dendritic/flake/home-configurations.nix"
if grep -q "\"${OLD_NAME}\"" "$HOME_CFG" || grep -q "/${OLD_NAME}/" "$HOME_CFG"; then
    sed -i \
        -e "s/\"${OLD_NAME}\"/\"${NEW_NAME}\"/g" \
        -e "s|/${OLD_NAME}/|/${NEW_NAME}/|g" \
        "$HOME_CFG"
    git add "$HOME_CFG"
    success "dendritic/flake/home-configurations.nix atualizado"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Passo 4 — Verificar segredos sops
# ─────────────────────────────────────────────────────────────────────────────

SECRETS_DIR="$REPO_ROOT/secrets"
SOPS_FILES=()
while IFS= read -r -d '' f; do
    SOPS_FILES+=("$f")
done < <(find "$SECRETS_DIR" -name '*.yaml' -print0 2>/dev/null)

if [[ ${#SOPS_FILES[@]} -gt 0 ]]; then
    SOPS_MATCHES=()
    for f in "${SOPS_FILES[@]}"; do
        # Decifrar só para inspecionar chaves; falha silenciosa se sem chave age
        if sops --decrypt "$f" 2>/dev/null | grep -q "${OLD_NAME}"; then
            SOPS_MATCHES+=("${f#"$REPO_ROOT/"}")
        fi
    done
    if [[ ${#SOPS_MATCHES[@]} -gt 0 ]]; then
        echo
        warn "Os seguintes arquivos sops contêm chaves com '${OLD_NAME}':"
        for f in "${SOPS_MATCHES[@]}"; do
            warn "  • ${f}"
        done
        warn "Renomeie as chaves manualmente após o script:"
        warn "  sops secrets/<arquivo>.yaml"
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# Concluído
# ─────────────────────────────────────────────────────────────────────────────

echo
success "Renomeação concluída: ${OLD_NAME} → ${NEW_NAME}"
echo

# ─────────────────────────────────────────────────────────────────────────────
# Passo 5 — nixos-rebuild switch (opcional)
# ─────────────────────────────────────────────────────────────────────────────

HOST="$(hostname)"
if confirm "Executar 'nixos-rebuild switch --flake /etc/nixos#${HOST}' agora?"; then
    echo
    info "Executando nixos-rebuild switch..."
    nixos-rebuild switch --flake "/etc/nixos#${HOST}"
    echo
    success "Sistema atualizado."
    echo
    warn "Execute home-manager switch para regenerar o ambiente do novo usuário:"
    warn "  home-manager switch --flake /etc/nixos#${NEW_NAME}@${HOST}"
else
    echo
    warn "Próximos passos:"
    warn "  1. nixos-rebuild switch --flake /etc/nixos#${HOST}"
    warn "  2. home-manager switch --flake /etc/nixos#${NEW_NAME}@${HOST}"
fi

echo
