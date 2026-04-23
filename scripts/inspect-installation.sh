#!/usr/bin/env bash
# inspect-installation.sh — Inspeciona uma instalação do NixOS feita pelo install.sh
#
# Execute este script a partir de um ambiente live do NixOS para verificar
# o estado de uma instalação já realizada pelo scripts/install.sh.
#
# O script verifica:
#   1. Montagem do sistema em /mnt (subvolumes Btrfs, etc.)
#   2. Instalação do NixOS (Nix store, perfis, bootloader)
#   3. Usuários definidos (/mnt/etc/passwd)
#   4. Estado das senhas (/mnt/etc/shadow e /mnt/persist/etc/shadow)
#   5. Configuração do flake (/mnt/etc/nixos)
#   6. Arquivos de usuário e imports em configuration.nix
#   7. Bind mounts ativos que afetam /mnt/etc/shadow
#
# Uso:
#   bash scripts/inspect-installation.sh [--root <path>] [--mount] [--help]
#
# Opções:
#   --root  <path>  Caminho raiz do sistema instalado (padrão: /mnt)
#   --mount         Tentar montar o sistema antes de inspecionar
#                   (requer que os subvolumes Btrfs estejam disponíveis)
#   --help, -h      Exibe esta ajuda e sai

set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers de saída
# ---------------------------------------------------------------------------

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

ok()     { echo -e "  ${GREEN}✔${RESET}  $*"; }
fail()   { echo -e "  ${RED}✖${RESET}  $*"; }
warn()   { echo -e "  ${YELLOW}⚠${RESET}  $*"; }
info()   { echo -e "  ${CYAN}ℹ${RESET}  $*"; }
section(){ echo; echo -e "${BOLD}${BLUE}══ $* ══${RESET}"; }

# ---------------------------------------------------------------------------
# Argumentos
# ---------------------------------------------------------------------------

ROOT=/mnt
DO_MOUNT=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)  ROOT="$2"; shift 2 ;;
    --mount) DO_MOUNT=true; shift ;;
    --help|-h)
      cat <<'EOF'
Uso:
  bash scripts/inspect-installation.sh [--root <path>] [--mount] [--help]

Opções:
  --root <path>  Caminho raiz do sistema instalado (padrão: /mnt)
  --mount        Tentar montar o sistema antes de inspecionar
  --help, -h     Exibe esta ajuda e sai
EOF
      exit 0 ;;
    *) echo "Opção desconhecida: $1. Use --help para ver as opções." >&2; exit 1 ;;
  esac
done

# Requer root para a maioria das operações
if [[ $EUID -ne 0 ]]; then
  echo "Este script deve ser executado como root (use sudo)." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# 0. Opcionalmente montar o sistema
# ---------------------------------------------------------------------------

if [[ "$DO_MOUNT" == "true" ]]; then
  section "Montando o sistema instalado em $ROOT"

  # Detectar o dispositivo de destino
  if [[ -b /dev/nvme0n1 ]]; then
    DISK=/dev/nvme0n1
  elif [[ -b /dev/sda ]]; then
    DISK=/dev/sda
  else
    warn "Não foi possível detectar o disco automaticamente."
    warn "Monte manualmente em $ROOT e execute novamente sem --mount."
    exit 1
  fi

  info "Disco detectado: $DISK"

  # Desbloquear LUKS se necessário
  if lsblk -o TYPE "$DISK" 2>/dev/null | grep -q crypt; then
    info "LUKS já desbloqueado."
  elif [[ -b "${DISK}p3" ]] || [[ -b "${DISK}3" ]]; then
    _luks_part="${DISK}p3"
    [[ -b "${DISK}3" ]] && _luks_part="${DISK}3"
    info "Tentando desbloquear LUKS em $_luks_part..."
    cryptsetup open "$_luks_part" cryptroot || warn "Falha ao desbloquear LUKS."
  fi

  # Montar volume group e subvolumes Btrfs
  if command -v vgchange >/dev/null 2>&1; then
    vgchange -ay 2>/dev/null || true
  fi

  _btrfs_dev=""
  for _candidate in /dev/mapper/vg-root /dev/mapper/cryptroot; do
    if [[ -b "$_candidate" ]]; then
      _btrfs_dev="$_candidate"
      break
    fi
  done
  # Fallback: procurar primeiro dispositivo Btrfs disponível
  if [[ -z "$_btrfs_dev" ]]; then
    _btrfs_dev=$(lsblk -o PATH,FSTYPE --noheadings 2>/dev/null \
      | awk '$2=="btrfs"{print $1; exit}' || true)
  fi

  if [[ -n "$_btrfs_dev" ]]; then
    info "Dispositivo Btrfs: $_btrfs_dev"
    mkdir -p "$ROOT"
    # A raiz é tmpfs no setup de impermanência; montar antes dos subvolumes
    mount -t tmpfs tmpfs "$ROOT" 2>/dev/null || true
    mkdir -p "$ROOT/nix" "$ROOT/persist" "$ROOT/home"
    mount -o subvol=@nix     "$_btrfs_dev" "$ROOT/nix"     2>/dev/null || true
    mount -o subvol=@persist "$_btrfs_dev" "$ROOT/persist" 2>/dev/null || true
    mount -o subvol=@home    "$_btrfs_dev" "$ROOT/home"    2>/dev/null || true
    # Montar /boot/efi se disponível
    _efi_part=""
    for _p in "${DISK}p1" "${DISK}1"; do
      [[ -b "$_p" ]] && _efi_part="$_p" && break
    done
    if [[ -n "$_efi_part" ]]; then
      mkdir -p "$ROOT/boot/efi"
      mount "$_efi_part" "$ROOT/boot/efi" 2>/dev/null || true
    fi
    ok "Subvolumes montados."
  else
    warn "Nenhum dispositivo Btrfs encontrado. Monte manualmente em $ROOT."
  fi
fi

# ---------------------------------------------------------------------------
# 1. Verificar montagem básica
# ---------------------------------------------------------------------------

section "1. Montagem do sistema em $ROOT"

_issues=0

_check_dir() {
  local path="$1" label="${2:-$1}"
  if [[ -d "$ROOT$path" ]]; then
    ok "$label existe ($ROOT$path)"
  else
    fail "$label não encontrado ($ROOT$path)"
    ((_issues++)) || true
  fi
}

_check_file() {
  local path="$1" label="${2:-$1}"
  if [[ -f "$ROOT$path" ]]; then
    ok "$label existe ($ROOT$path)"
  else
    fail "$label não encontrado ($ROOT$path)"
    ((_issues++)) || true
  fi
}

_check_dir "" "Raiz do sistema instalado"
_check_dir "/nix/store" "Nix store"
_check_dir "/persist" "/persist (subvolume Btrfs)"
_check_dir "/home" "/home (subvolume Btrfs)"
_check_dir "/nix" "/nix (subvolume Btrfs)"

# Verificar se é um tmpfs (root deve ser tmpfs em impermanence)
if findmnt --target "$ROOT" --output FSTYPE --noheadings 2>/dev/null | grep -q tmpfs; then
  ok "Raiz ($ROOT) é tmpfs (impermanence ativo)"
elif findmnt --target "$ROOT" --output FSTYPE --noheadings 2>/dev/null | grep -q btrfs; then
  warn "Raiz ($ROOT) é Btrfs — esperado tmpfs para impermanence"
else
  info "Tipo de filesystem da raiz: $(findmnt --target "$ROOT" --output FSTYPE --noheadings 2>/dev/null || echo 'desconhecido')"
fi

# Verificar subvolumes Btrfs
if command -v btrfs >/dev/null 2>&1; then
  _btrfs_root=$(findmnt --target "$ROOT/persist" --output SOURCE --noheadings 2>/dev/null || true)
  if [[ -n "$_btrfs_root" ]]; then
    info "Subvolumes Btrfs montados em $ROOT/persist:"
    btrfs subvolume list "$ROOT/persist" 2>/dev/null | sed 's/^/    /' || true
  fi
fi

# ---------------------------------------------------------------------------
# 2. Verificar instalação do NixOS
# ---------------------------------------------------------------------------

section "2. Instalação do NixOS"

if [[ -L "$ROOT/run/current-system" ]]; then
  _sys="$ROOT/run/current-system"
  ok "Perfil do sistema: $(readlink -f "$_sys" 2>/dev/null || echo 'desconhecido')"
elif [[ -L "$ROOT/nix/var/nix/profiles/system" ]]; then
  ok "Perfil do sistema: $(readlink -f "$ROOT/nix/var/nix/profiles/system" 2>/dev/null)"
else
  fail "Perfil do sistema NixOS não encontrado"
  ((_issues++)) || true
fi

# Verificar bootloader
if [[ -d "$ROOT/boot/efi" ]]; then
  ok "/boot/efi montado"
  if [[ -d "$ROOT/boot/efi/EFI/nixos" ]]; then
    ok "Entradas EFI do NixOS presentes"
  elif [[ -d "$ROOT/boot/efi/EFI" ]]; then
    warn "Diretório EFI existe mas sem entradas NixOS"
  else
    fail "Nenhuma entrada EFI encontrada"
    ((_issues++)) || true
  fi
else
  warn "/boot/efi não montado (bootloader não inspecionado)"
fi

# Lanzaboote / systemd-boot
if [[ -d "$ROOT/boot/efi/EFI/Linux" ]]; then
  ok "Lanzaboote: imagens de kernel assinadas presentes em /boot/efi/EFI/Linux"
fi

# Chaves Secure Boot
if [[ -f "$ROOT/persist/etc/secureboot/GUID" ]]; then
  ok "Chaves Secure Boot presentes em /persist/etc/secureboot/"
  info "Para registrar no firmware: sbctl enroll-keys --microsoft"
else
  info "Chaves Secure Boot não encontradas em /persist/etc/secureboot/ (pode ser normal)"
fi

# ---------------------------------------------------------------------------
# 3. Usuários definidos
# ---------------------------------------------------------------------------

section "3. Usuários definidos (/etc/passwd)"

if [[ -f "$ROOT/etc/passwd" ]]; then
  ok "/etc/passwd encontrado"
  # Mostrar usuários normais (UID >= 1000, exceto nobody)
  _normal_users=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1, "(UID=" $3 ")"}' \
    "$ROOT/etc/passwd" || true)
  if [[ -n "$_normal_users" ]]; then
    ok "Usuários normais definidos:"
    echo "$_normal_users" | while read -r _line; do
      info "  → $_line"
    done
  else
    fail "Nenhum usuário normal (UID >= 1000) encontrado em /etc/passwd"
    warn "Verifique se os imports de usuário estão em hosts/*/configuration.nix"
    warn "e se o nixos-install foi concluído com sucesso."
    ((_issues++)) || true
  fi
else
  fail "/etc/passwd não encontrado — o NixOS provavelmente não foi instalado"
  ((_issues++)) || true
fi

# ---------------------------------------------------------------------------
# 4. Estado das senhas
# ---------------------------------------------------------------------------

section "4. Estado das senhas"

# Função auxiliar: decodifica o estado de senha do campo hash no shadow
_password_status() {
  local hash="$1"
  case "$hash" in
    '!')  echo "bloqueada (sem login por senha)" ;;
    '!!'| '*') echo "não definida" ;;
    '$'*) echo "definida (hash presente)" ;;
    '')   echo "vazia (sem senha — INSEGURO)" ;;
    *)    echo "estado desconhecido: $hash" ;;
  esac
}

# --- /mnt/etc/shadow ---
echo
info "==> /mnt/etc/shadow (shadow gerado pelo NixOS activation)"
if [[ -f "$ROOT/etc/shadow" ]]; then
  ok "/etc/shadow encontrado"
  # Verificar se é um bind mount (para /persist/etc/shadow)
  _shadow_mountsrc=$(findmnt --target "$ROOT/etc/shadow" --output SOURCE --noheadings 2>/dev/null || true)
  if [[ -n "$_shadow_mountsrc" ]]; then
    warn "/etc/shadow está bind-montado de: $_shadow_mountsrc"
    info "Isso é esperado APÓS o primeiro boot (restoreShadow bind monta /persist/etc/shadow)."
    info "Durante a instalação (antes do primeiro boot), /etc/shadow NÃO deve estar bind-montado."
  fi

  # Mostrar estado de senha para usuários relevantes
  while IFS=: read -r _user _hash _rest; do
    case "$_user" in
      root|nobody|systemd-*|messagebus|polkituser) ;;  # skip system accounts
      *) [[ -z "$_rest" ]] && continue ;;  # pular se linha malformada
    esac
    # Mostrar root e usuários normais
    _uid=$(grep "^${_user}:" "$ROOT/etc/passwd" 2>/dev/null | cut -d: -f3 || echo "")
    if [[ "$_user" == "root" ]] || { [[ -n "$_uid" ]] && [[ "$_uid" -ge 1000 ]] 2>/dev/null; }; then
      info "  $_user: $(_password_status "$_hash")"
    fi
  done < "$ROOT/etc/shadow" 2>/dev/null || true
else
  fail "/etc/shadow não encontrado"
  ((_issues++)) || true
fi

# --- /mnt/persist/etc/shadow ---
echo
info "==> /mnt/persist/etc/shadow (shadow persistido entre boots)"
if [[ -f "$ROOT/persist/etc/shadow" ]]; then
  ok "/persist/etc/shadow encontrado"
  _has_password=false
  while IFS=: read -r _user _hash _rest; do
    _uid=$(grep "^${_user}:" "$ROOT/etc/passwd" 2>/dev/null | cut -d: -f3 || echo "")
    if [[ "$_user" == "root" ]] || { [[ -n "$_uid" ]] && [[ "$_uid" -ge 1000 ]] 2>/dev/null; }; then
      _status=$(_password_status "$_hash")
      info "  $_user: $_status"
      [[ "$_hash" == '$'* ]] && _has_password=true
    fi
  done < "$ROOT/persist/etc/shadow" 2>/dev/null || true
  if [[ "$_has_password" == "false" ]]; then
    warn "Nenhum usuário ou root com senha definida em /persist/etc/shadow."
    warn "As senhas podem ter sido perdidas. Verifique o passo 8 do install.sh."
  fi
else
  fail "/persist/etc/shadow não encontrado"
  warn "Sem esse arquivo, as senhas serão perdidas no primeiro boot."
  warn "Execute o passo 8 do install.sh para definir senhas e copiar o shadow."
  ((_issues++)) || true
fi

# Comparar /etc/shadow e /persist/etc/shadow
if [[ -f "$ROOT/etc/shadow" && -f "$ROOT/persist/etc/shadow" ]]; then
  if cmp -s "$ROOT/etc/shadow" "$ROOT/persist/etc/shadow"; then
    info "/etc/shadow e /persist/etc/shadow são idênticos (nenhuma senha diferenciada)"
  else
    _diff=$(diff "$ROOT/etc/shadow" "$ROOT/persist/etc/shadow" 2>/dev/null | head -20 || true)
    if [[ -n "$_diff" ]]; then
      info "/etc/shadow e /persist/etc/shadow diferem (estado esperado após definir senhas):"
      echo "$_diff" | sed 's/^/    /'
    fi
  fi
fi

# Flag files de troca de senha
echo
info "==> Arquivos de flag de troca de senha (/persist/.password-change-required-*)"
_flags=$(ls -1 "$ROOT/persist/.password-change-required-"* 2>/dev/null || true)
if [[ -n "$_flags" ]]; then
  ok "Flags de senha pré-definida encontradas (sem troca forçada no primeiro login):"
  echo "$_flags" | while read -r _f; do
    info "  $_f"
  done
else
  info "Nenhuma flag de senha pré-definida encontrada."
  info "(Os usuários com initialPassword='nixos' terão troca de senha forçada no 1º login)"
fi

# ---------------------------------------------------------------------------
# 5. Configuração do flake (/etc/nixos)
# ---------------------------------------------------------------------------

section "5. Configuração do flake (/etc/nixos)"

if [[ -d "$ROOT/etc/nixos" ]]; then
  ok "/etc/nixos existe"

  if [[ -f "$ROOT/etc/nixos/flake.nix" ]]; then
    ok "flake.nix encontrado"
  else
    fail "flake.nix não encontrado em /etc/nixos"
    ((_issues++)) || true
  fi

  if [[ -f "$ROOT/etc/nixos/flake.lock" ]]; then
    ok "flake.lock encontrado"
  else
    warn "flake.lock não encontrado (pode causar problemas com nixos-rebuild)"
  fi

  # Verificar índice git
  if [[ -d "$ROOT/etc/nixos/.git" ]]; then
    ok "Repositório git encontrado em /etc/nixos"
    info "Status do índice git:"
    git -C "$ROOT/etc/nixos" status --short 2>/dev/null | sed 's/^/    /' \
      || info "    (não foi possível obter status)"
    # Listar arquivos staged (no índice)
    info "Arquivos no índice git (staged):"
    git -C "$ROOT/etc/nixos" ls-files 2>/dev/null | grep -E '^(users/|hosts/|private/)' \
      | sed 's/^/    /' \
      || info "    (não foi possível listar)"
  else
    warn ".git não encontrado em /etc/nixos — Nix avaliará como diretório simples"
    info "(Todos os arquivos presentes serão incluídos na avaliação do flake)"
  fi
else
  fail "/etc/nixos não encontrado"
  ((_issues++)) || true
fi

# ---------------------------------------------------------------------------
# 6. Arquivos de usuário e imports em configuration.nix
# ---------------------------------------------------------------------------

section "6. Arquivos de usuário e imports"

# Detectar hosts disponíveis
_hosts=()
if [[ -d "$ROOT/etc/nixos/hosts" ]]; then
  while IFS= read -r _h; do
    _hosts+=("$_h")
  done < <(ls -1 "$ROOT/etc/nixos/hosts/" 2>/dev/null || true)
fi

if [[ ${#_hosts[@]} -eq 0 ]]; then
  warn "Nenhum host encontrado em /etc/nixos/hosts/"
else
  info "Hosts disponíveis: ${_hosts[*]}"
fi

# Verificar arquivos de usuário em /etc/nixos/users/
echo
info "==> Arquivos de usuário em /etc/nixos/users/"
_user_files=$(ls -1 "$ROOT/etc/nixos/users/"*.nix 2>/dev/null \
  | grep -v "skeleton.nix" || true)
if [[ -n "$_user_files" ]]; then
  ok "Arquivos de usuário encontrados:"
  echo "$_user_files" | while read -r _f; do
    _fname=$(basename "$_f")
    _username="${_fname%.nix}"
    # Verificar se está no índice git
    if [[ -d "$ROOT/etc/nixos/.git" ]]; then
      if git -C "$ROOT/etc/nixos" ls-files --error-unmatch "users/$_fname" &>/dev/null; then
        info "  ✔ users/$_fname (indexado no git — visível ao Nix)"
      else
        fail "  ✖ users/$_fname (NÃO indexado no git — invisível ao Nix!)"
        warn "    Execute: git -C $ROOT/etc/nixos add --force users/$_fname"
        ((_issues++)) || true
      fi
    else
      info "  → users/$_fname"
    fi
    # Verificar se o usuário está em /etc/passwd
    if grep -q "^${_username}:" "$ROOT/etc/passwd" 2>/dev/null; then
      info "    └─ usuário '$_username' presente em /etc/passwd ✔"
    else
      warn "    └─ usuário '$_username' NÃO encontrado em /etc/passwd"
      warn "       O import pode estar faltando em configuration.nix, ou o nixos-install falhou."
    fi
  done
else
  warn "Nenhum arquivo de usuário encontrado em /etc/nixos/users/"
  info "(Apenas users/skeleton.nix encontrado ou diretório vazio)"
fi

# Verificar imports em configuration.nix de cada host
echo
for _host in "${_hosts[@]}"; do
  _cfgfile="$ROOT/etc/nixos/hosts/$_host/configuration.nix"
  if [[ ! -f "$_cfgfile" ]]; then
    continue
  fi
  info "==> Imports de usuário em hosts/$_host/configuration.nix:"
  _user_imports=$(grep -E '^\s+\.\/\.\.\/(\.\.\/)?users/[^.]+\.nix' "$_cfgfile" 2>/dev/null || true)
  _placeholder=$(grep -E '#.*seu-usuario\.nix|#.*<seu-usuario>' "$_cfgfile" 2>/dev/null || true)
  if [[ -n "$_user_imports" ]]; then
    ok "Imports de usuário encontrados:"
    echo "$_user_imports" | while read -r _line; do
      info "  $_line"
    done
  elif [[ -n "$_placeholder" ]]; then
    fail "Apenas placeholder comentado encontrado (nenhum usuário importado):"
    echo "$_placeholder" | while read -r _line; do
      warn "  $_line"
    done
    warn "O install.sh deveria ter substituído o placeholder pelo import real."
    ((_issues++)) || true
  else
    warn "Nenhum import de usuário encontrado em hosts/$_host/configuration.nix"
  fi
done

# Camada privada
echo
if [[ -f "$ROOT/etc/nixos/private/modules.nix" ]]; then
  ok "Camada privada encontrada em /etc/nixos/private/"
  if [[ -d "$ROOT/etc/nixos/.git" ]]; then
    if git -C "$ROOT/etc/nixos" ls-files "private/" 2>/dev/null | grep -q .; then
      ok "Camada privada indexada no git (visível ao Nix)"
    else
      fail "Camada privada NÃO indexada no git!"
      warn "Execute: git -C $ROOT/etc/nixos add --force private/"
      ((_issues++)) || true
    fi
  fi
else
  info "Camada privada não encontrada (normal se não usada)"
fi

# ---------------------------------------------------------------------------
# 7. Bind mounts ativos em /etc/shadow
# ---------------------------------------------------------------------------

section "7. Bind mounts em /mnt/etc/shadow"

_shadow_mount=$(findmnt --target "$ROOT/etc/shadow" --output SOURCE,TARGET,FSTYPE --noheadings \
  2>/dev/null || true)
if [[ -n "$_shadow_mount" ]]; then
  warn "Bind mount ATIVO em $ROOT/etc/shadow:"
  echo "  $_shadow_mount"
  warn "Isso significa que o script de ativação 'restoreShadow' do nixos-install"
  warn "propagou o bind mount para o namespace do live CD."
  warn ""
  warn "ATENÇÃO: Se você definir senhas agora com nixos-enter, elas serão escritas em"
  warn "/mnt/persist/etc/shadow via bind mount. Mas o comando final do install.sh"
  warn "  install -m 640 /mnt/etc/shadow /mnt/persist/etc/shadow"
  warn "usaria /mnt/etc/shadow (= /mnt/persist/etc/shadow via bind mount) como fonte,"
  warn "o que seria correto nesse caso. Use passwd --root /mnt para evitar ambiguidades."
else
  ok "Nenhum bind mount ativo em $ROOT/etc/shadow (estado esperado antes do 1º boot)"
fi

# ---------------------------------------------------------------------------
# Sumário
# ---------------------------------------------------------------------------

section "Sumário"

if [[ "$_issues" -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}✔ Nenhum problema detectado.${RESET}"
  echo "  A instalação parece estar em bom estado."
else
  echo -e "${RED}${BOLD}✖ ${_issues} problema(s) encontrado(s).${RESET}"
  echo "  Verifique os itens marcados com ✖ ou ⚠ acima."
fi

echo
echo -e "${BOLD}Próximos passos comuns:${RESET}"
echo "  • Se senhas não foram definidas:"
echo "      passwd --root /mnt <usuario>"
echo "      passwd --root /mnt root"
echo "      install -m 640 /mnt/etc/shadow /mnt/persist/etc/shadow"
echo "  • Se arquivos de usuário não estão indexados:"
echo "      git -C /mnt/etc/nixos add --force users/<usuario>.nix"
echo "      nixos-install --flake /mnt/etc/nixos#<host>"
echo "  • Se o sistema ainda não foi instalado:"
echo "      bash scripts/install.sh"
echo "  • Para desmontar e reiniciar:"
echo "      umount -R /mnt && reboot"
echo
