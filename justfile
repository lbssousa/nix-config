set shell := ["bash", "-euo", "pipefail", "-c"]

flake_root := env_var_or_default("LBNIX_FLAKE_DIR", justfile_directory())
justfile_file := justfile_directory() + "/justfile"

[private]
_run_system action host='' *args:
  #!/usr/bin/env bash
  set -euo pipefail

  action="{{action}}"
  system_host="{{host}}"
  set -- {{args}}

  system_host="${system_host:-$(hostname)}"

  case "$action" in
    switch|boot|test)
      if [[ "${EUID}" -ne 0 ]]; then
        exec sudo nix run nixpkgs#just -- --justfile "{{justfile_file}}" _run_system "$action" "$system_host" "$@"
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
      echo "Ação inválida para _run_system: '$action'" >&2
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
  @echo 'switch, boot e test elevam com sudo quando necessário.'
  @echo 'Home Manager é aplicado junto com nixos-rebuild (módulo do sistema).'
  @echo ''
  @echo 'Exemplos:'
  @echo '  just switch'
  @echo '  just switch barbudus'
  @echo '  just switch-full barbudus'
  @echo '  just boot'
  @echo '  just diff'
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

switch host='' *args:
  nix run nixpkgs#just -- --justfile "{{justfile_file}}" _run_system switch "{{host}}" {{args}}

boot host='' *args:
  nix run nixpkgs#just -- --justfile "{{justfile_file}}" _run_system boot "{{host}}" {{args}}

test host='' *args:
  nix run nixpkgs#just -- --justfile "{{justfile_file}}" _run_system test "{{host}}" {{args}}

build host='' *args:
  nix run nixpkgs#just -- --justfile "{{justfile_file}}" _run_system build "{{host}}" {{args}}

diff host='' *args:
  nix run nixpkgs#just -- --justfile "{{justfile_file}}" _run_system diff "{{host}}" {{args}}

switch-full host='' *args:
  nix run nixpkgs#just -- --justfile "{{justfile_file}}" switch "{{host}}" {{args}}
  nix run nixpkgs#just -- --justfile "{{justfile_file}}" check

upgrade host='' *args:
  nix run nixpkgs#just -- --justfile "{{justfile_file}}" update
  nix run nixpkgs#just -- --justfile "{{justfile_file}}" switch "{{host}}" {{args}}

[group("maintenance")]
update *inputs:
  #!/usr/bin/env bash
  set -euo pipefail
  cd "{{flake_root}}"
  nix flake update "$@"

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
  nix run nixpkgs#nixfmt-rfc-style -- $(find . -name '*.nix' -not -path './.git/*')

[group("verification")]
fmt-check:
  #!/usr/bin/env bash
  set -euo pipefail
  cd "{{flake_root}}"
  nix run nixpkgs#nixfmt-rfc-style -- --check $(find . -name '*.nix' -not -path './.git/*')

[group("verification")]
validate:
  nix run nixpkgs#just -- --justfile "{{justfile_file}}" fmt-check
  nix run nixpkgs#just -- --justfile "{{justfile_file}}" lint
  nix run nixpkgs#just -- --justfile "{{justfile_file}}" deadcode
  nix run nixpkgs#just -- --justfile "{{justfile_file}}" check --show-trace
