set shell := ["bash", "-euo", "pipefail", "-c"]

flake_root := env_var_or_default("FLAKE_DIR", justfile_directory())
justfile_file := justfile_directory() + "/justfile"

# Quando "true", commit e push do flake.lock são feitos automaticamente após
# update/upgrade, caso o arquivo tenha sido modificado.
# Uso: just auto_commit=false update   ou   AUTO_COMMIT=false just update
auto_commit := env_var_or_default("AUTO_COMMIT", "true")

u2f_authfile := "/persist/etc/u2f-mappings"

[private]
_run_nixos action host='' *args:
  #!/usr/bin/env bash
  set -euo pipefail

  action="{{action}}"
  system_host="{{host}}"
  set -- {{args}}

  system_host="${system_host:-$(hostname)}"

  case "$action" in
    switch|boot|test)
      if [[ "${EUID}" -ne 0 ]]; then
        exec run0 --setenv=SSH_AUTH_SOCK="${SSH_AUTH_SOCK:-}" nix run nixpkgs#just -- --justfile "{{justfile_file}}" _run_nixos "$action" "$system_host" "$@"
      fi
      ;;
  esac

  case "$action" in
    switch|boot|test|build)
      nixos-rebuild "$action" --flake "{{flake_root}}#${system_host}" "$@"
      ;;
    diff)
      next_drv="$(
        nix build \
          "{{flake_root}}#nixosConfigurations.${system_host}.config.system.build.toplevel" \
          --no-link \
          --print-out-paths \
          2>/dev/null
      )"
      nix run nixpkgs#nvd -- diff /run/current-system "$next_drv"
      ;;
    *)
      echo "Ação inválida para nixos: '$action'" >&2
      exit 1
      ;;
  esac

default:
  @nix run nixpkgs#just -- --justfile "{{justfile_file}}" help

[group("help")]
help:
  @echo 'Receitas Just para operar este flake NixOS'
  @echo ''
  @echo "FLAKE_DIR atual: {{flake_root}}"
  @echo 'switch, boot e test elevam com run0 (polkit/YubiKey) quando necessário.'
  @echo 'Home Manager é módulo NixOS: just switch aplica NixOS + HM em conjunto.'
  @echo 'just upgrade atualiza os inputs e em seguida aplica switch.'
  @echo ''
  @echo 'Exemplos:'
  @echo '  just update'
  @echo '  just auto_commit=false update'
  @echo '  just auto_commit=false upgrade'
  @echo '  just switch'
  @echo '  just switch barbudus'
  @echo '  just nixos switch barbudus'
  @echo '  just nixos diff'
  @echo '  just nixos test'
  @echo ''
  @nix run nixpkgs#just -- --justfile "{{justfile_file}}" --list --unsorted

[group("info")]
show:
  cd "{{flake_root}}" && nix flake show

[group("info")]
systems:
  #!/usr/bin/env bash
  set -euo pipefail
  cd "{{flake_root}}"
  nix eval --json .#nixosConfigurations --apply builtins.attrNames | jq -r '.[]'

[group("info")]
whoami:
  @echo "host: $(hostname)"
  @echo "usuário: $(whoami)"
  @echo "flake: {{flake_root}}"

nixos action='' host='' *args:
  nix run nixpkgs#just -- --justfile "{{justfile_file}}" _run_nixos "{{action}}" "{{host}}" {{args}}

switch host='' *args:
  nix run nixpkgs#just -- --justfile "{{justfile_file}}" _run_nixos switch "{{host}}" {{args}}

boot host='' *args:
  nix run nixpkgs#just -- --justfile "{{justfile_file}}" _run_nixos boot "{{host}}" {{args}}

test host='' *args:
  nix run nixpkgs#just -- --justfile "{{justfile_file}}" _run_nixos test "{{host}}" {{args}}

build host='' *args:
  nix run nixpkgs#just -- --justfile "{{justfile_file}}" _run_nixos build "{{host}}" {{args}}

diff host='' *args:
  nix run nixpkgs#just -- --justfile "{{justfile_file}}" _run_nixos diff "{{host}}" {{args}}

switch-full host='' *args:
  nix run nixpkgs#just -- --justfile "{{justfile_file}}" switch "{{host}}" {{args}}
  nix run nixpkgs#just -- --justfile "{{justfile_file}}" check

upgrade host='' *args:
  nix run nixpkgs#just -- --justfile "{{justfile_file}}" auto_commit="{{auto_commit}}" update
  nix run nixpkgs#just -- --justfile "{{justfile_file}}" switch "{{host}}" {{args}}

[group("maintenance")]
update *inputs:
  #!/usr/bin/env bash
  set -euo pipefail
  cd "{{flake_root}}"
  nix flake update "$@"
  if [[ "{{auto_commit}}" == "true" ]] && ! git diff --quiet flake.lock; then
    git add flake.lock
    git commit -m "flake: atualiza flake.lock"
    git push
  fi

[group("maintenance")]
gc period='30d':
  #!/usr/bin/env bash
  set -euo pipefail
  period_spec="${1:-30d}"

  case "$period_spec" in
    full)
      nix-collect-garbage --delete-old
      ;;
    *)
      nix-collect-garbage --delete-older-than "$period_spec"
      ;;
  esac

[group("verification")]
check *args:
  #!/usr/bin/env bash
  set -euo pipefail
  cd "{{flake_root}}"
  nix flake check "$@"

[group("verification")]
lint:
  cd "{{flake_root}}" && nix run nixpkgs#statix -- check .

[group("verification")]
deadcode:
  cd "{{flake_root}}" && nix run nixpkgs#deadnix -- --fail .

[group("verification")]
fmt:
  #!/usr/bin/env bash
  set -euo pipefail
  cd "{{flake_root}}"
  nix run nixpkgs#nixfmt -- $(find . -name '*.nix' -not -path './.git/*')

[group("verification")]
fmt-check:
  #!/usr/bin/env bash
  set -euo pipefail
  cd "{{flake_root}}"
  nix run nixpkgs#nixfmt -- --check $(find . -name '*.nix' -not -path './.git/*')

[group("verification")]
hooks:
  git config core.hooksPath .githooks
  @echo "✅ Git hooks configurados em .githooks/"

[group("verification")]
validate:
  nix run nixpkgs#just -- --justfile "{{justfile_file}}" fmt-check
  nix run nixpkgs#just -- --justfile "{{justfile_file}}" lint
  nix run nixpkgs#just -- --justfile "{{justfile_file}}" deadcode
  nix run nixpkgs#just -- --justfile "{{justfile_file}}" check --show-trace

# Registra uma YubiKey no authfile do sistema para o usuário indicado (padrão: usuário atual).
# Primeira chave: cria a linha no authfile. Chave adicional: acrescenta à linha existente.
# Referência: security/yubikey/setup.sh (dotfiles)
[group("yubikey")]
yubikey-register usuario='':
  #!/usr/bin/env bash
  set -euo pipefail
  authfile="{{u2f_authfile}}"
  alvo="{{usuario}}"
  alvo="${alvo:-$(id -un)}"

  echo "Registrando YubiKey para '${alvo}'..."
  echo "Insira a YubiKey e toque-a quando solicitado."
  echo ""

  if [ -f "${authfile}" ] && grep -q "^${alvo}:" "${authfile}"; then
    nova_cred=$(pamu2fcfg -n -u "${alvo}")
    run0 sed -i "/^${alvo}:/ s|$|:${nova_cred}|" "${authfile}"
    echo "Chave adicional registrada para '${alvo}'."
  else
    nova_linha=$(pamu2fcfg -u "${alvo}")
    printf '%s\n' "${nova_linha}" | run0 tee -a "${authfile}" > /dev/null
    echo "Primeira chave registrada para '${alvo}'."
  fi

  echo ""
  n=$(grep "^${alvo}:" "${authfile}" | tr ':' '\n' | tail -n +2 | grep ',' | wc -l)
  echo "Total de chaves para '${alvo}': ${n}"

# Remove todas as chaves de um usuário do authfile (pede confirmação).
# Referência: security/yubikey/uninstall.sh (dotfiles)
[group("yubikey")]
yubikey-remove usuario:
  #!/usr/bin/env bash
  set -euo pipefail
  authfile="{{u2f_authfile}}"
  alvo="{{usuario}}"

  if [ ! -f "${authfile}" ] || ! grep -q "^${alvo}:" "${authfile}"; then
    echo "Nenhuma chave registrada para '${alvo}'."
    exit 0
  fi

  n=$(grep "^${alvo}:" "${authfile}" | tr ':' '\n' | tail -n +2 | grep ',' | wc -l)
  read -rp "Remover ${n} chave(s) de '${alvo}'? [s/N] " resposta
  case "${resposta}" in
    [sS]*)
      run0 sed -i "/^${alvo}:/d" "${authfile}"
      echo "Entradas de '${alvo}' removidas do authfile."
      ;;
    *)
      echo "Operação cancelada."
      ;;
  esac

# Lista chaves U2F registradas. Sem argumento: todos os usuários com contagem.
[group("yubikey")]
yubikey-list usuario='':
  #!/usr/bin/env bash
  set -euo pipefail
  authfile="{{u2f_authfile}}"
  filtro="{{usuario}}"

  if [ ! -f "${authfile}" ]; then
    echo "Authfile não encontrado: ${authfile}"
    exit 1
  fi

  if [ -n "${filtro}" ]; then
    if grep -q "^${filtro}:" "${authfile}"; then
      n=$(grep "^${filtro}:" "${authfile}" | tr ':' '\n' | tail -n +2 | grep ',' | wc -l)
      echo "${filtro}: ${n} chave(s) registrada(s)"
    else
      echo "Nenhuma chave registrada para '${filtro}'."
    fi
  else
    while IFS= read -r linha; do
      u="${linha%%:*}"
      n=$(printf '%s' "${linha#*:}" | tr ':' '\n' | grep ',' | wc -l)
      printf "%-20s %s chave(s)\n" "${u}" "${n}"
    done < "${authfile}"
  fi

# Verifica hardware, authfile e stack PAM para diagnóstico de autenticação U2F.
# Referência: security/yubikey/troubleshoot.sh (dotfiles)
[group("yubikey")]
yubikey-check:
  #!/usr/bin/env bash
  set -euo pipefail
  authfile="{{u2f_authfile}}"
  usuario=$(id -un)

  echo "=== Diagnóstico U2F/FIDO2 ==="
  echo ""

  echo "Hardware:"
  if lsusb 2>/dev/null | grep -qi yubico; then
    echo "  OK  YubiKey detectada via USB"
    lsusb | grep -i yubico | sed 's/^/       /'
  else
    echo "  --  YubiKey não detectada (conecte a YubiKey)"
  fi

  echo ""
  echo "Authfile (${authfile}):"
  if [ -f "${authfile}" ]; then
    echo "  OK  Arquivo existe"
    if grep -q "^${usuario}:" "${authfile}"; then
      n=$(grep "^${usuario}:" "${authfile}" | tr ':' '\n' | tail -n +2 | grep ',' | wc -l)
      echo "  OK  ${n} chave(s) para '${usuario}'"
    else
      echo "  --  Sem entrada para '${usuario}' — execute: just yubikey-register"
    fi
    echo ""
    echo "  Usuários registrados:"
    while IFS= read -r linha; do
      u="${linha%%:*}"
      n=$(printf '%s' "${linha#*:}" | tr ':' '\n' | grep ',' | wc -l)
      printf "       %-20s %s chave(s)\n" "${u}" "${n}"
    done < "${authfile}"
  else
    echo "  --  Authfile não encontrado — execute: just yubikey-register"
  fi

  echo ""
  echo "PAM sudo (auth):"
  grep "^auth" /etc/pam.d/sudo | sed 's|/nix/store/[^/]*/||g; s/^/  /'

# Testa a autenticação interativa (digital → YubiKey → senha) via run0.
[group("yubikey")]
yubikey-test:
  #!/usr/bin/env bash
  set -euo pipefail
  echo "Testando autenticação (digital → YubiKey → senha)..."
  echo ""
  if run0 true; then
    echo ""
    echo "OK  Autenticação bem-sucedida."
  else
    echo ""
    echo "--  Falha na autenticação."
    exit 1
  fi
