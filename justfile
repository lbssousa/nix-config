set shell := ["bash", "-euo", "pipefail", "-c"]

flake_root := env_var_or_default("LBNIX_FLAKE_DIR", justfile_directory())
justfile_file := justfile_directory() + "/justfile"

# Quando "true", commit e push do flake.lock são feitos automaticamente após
# update/upgrade, caso o arquivo tenha sido modificado.
# Uso: just auto_commit=true update   ou   LBNIX_AUTO_COMMIT=true just update
auto_commit := env_var_or_default("LBNIX_AUTO_COMMIT", "false")

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

[private]
_run_home action user='' *args:
  #!/usr/bin/env bash
  set -euo pipefail

  action="{{action}}"
  user_host="{{user}}"
  set -- {{args}}

  user_host="${user_host:-$(whoami)@$(hostname)}"

  case "$action" in
    switch|build)
      home-manager "$action" --flake "{{flake_root}}#${user_host}" "$@"
      ;;
    *)
      echo "Ação inválida para home: '$action'. Use: switch, build" >&2
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
  @echo 'just switch aplica nixos switch e home switch em sequência.'
  @echo 'just upgrade atualiza os inputs e em seguida aplica switch (nixos + home).'
  @echo ''
  @echo 'Exemplos:'
  @echo '  just update'
  @echo '  just auto_commit=true update'
  @echo '  just auto_commit=true upgrade'
  @echo '  just nixos switch'
  @echo '  just nixos switch barbudus'
  @echo '  just nixos diff'
  @echo '  just home switch'
  @echo '  just home switch abutre@barbudus'
  @echo '  just switch-full barbudus'
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

home action='' user='' *args:
  nix run nixpkgs#just -- --justfile "{{justfile_file}}" _run_home "{{action}}" "{{user}}" {{args}}

switch host='' *args:
  nix run nixpkgs#just -- --justfile "{{justfile_file}}" _run_nixos switch "{{host}}" {{args}}
  nix run nixpkgs#just -- --justfile "{{justfile_file}}" _run_home switch

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
