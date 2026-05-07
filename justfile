set shell := ["bash", "-euo", "pipefail", "-c"]

flake_root := env_var_or_default("LBNIX_FLAKE_DIR", justfile_directory())
justfile_file := justfile_directory() + "/justfile"

[private]
_run_system action host='' desktop='gnome' *args:
  #!/usr/bin/env bash
  set -euo pipefail

  action="{{action}}"
  system_host="{{host}}"
  desktop_name="{{desktop}}"

  system_host="${system_host:-$(hostname)}"
  desktop_name="${desktop_name:-gnome}"

  case "$desktop_name" in
    ''|default)
      flake_target="$system_host"
      ;;
    gnome|plasma)
      flake_target="${system_host}-${desktop_name}"
      ;;
    *)
      echo "Desktop inválido: '$desktop_name' (use gnome|plasma|default)" >&2
      exit 1
      ;;
  esac

  case "$action" in
    switch|boot|test|build)
      nixos-rebuild "$action" --flake "{{flake_root}}#${flake_target}" {{args}}
      ;;
    diff)
      next_drv="$(
        nix build \
          "{{flake_root}}#nixosConfigurations.${flake_target}.config.system.build.toplevel" \
          --no-link \
          --print-out-paths \
          2>/dev/null
      )"
      nix run nixpkgs#nvd -- diff /run/current-system "$next_drv"
      ;;
    *)
      echo "Ação de sistema inválida: '$action'" >&2
      exit 1
      ;;
  esac

[private]
_run_home action target='' desktop='' *args:
  #!/usr/bin/env bash
  set -euo pipefail

  action="{{action}}"
  current_host="$(hostname)"
  home_target="{{target}}"
  desktop_name="{{desktop}}"

  home_target="${home_target:-$(whoami)@${current_host}}"

  if [[ "$home_target" != *@* ]]; then
    home_target="${home_target}@${current_host}"
  fi

  case "$desktop_name" in
    ''|default)
      ;;
    gnome|plasma)
      home_target="${home_target}-${desktop_name}"
      ;;
    *)
      echo "Desktop inválido: '$desktop_name' (use gnome|plasma|default)" >&2
      exit 1
      ;;
  esac

  case "$action" in
    switch|news)
      home-manager "$action" --flake "{{flake_root}}#${home_target}" {{args}}
      ;;
    packages)
      cd "{{flake_root}}"
      nix eval --json ".#homeConfigurations.\"${home_target}\".config.home.packages" \
        --apply 'builtins.map (pkg: pkg.name or "<sem-nome>")' \
        | jq -r '.[]'
      ;;
    *)
      echo "Ação de home inválida: '$action'" >&2
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
  @echo 'Desktop aceito: gnome, plasma ou default'
  @echo 'As receitas no namespace system exigem sudo.'
  @echo ''
  @echo 'Exemplos:'
  @echo '  sudo just system switch'
  @echo '  sudo just system switch-full barbudus plasma'
  @echo '  just home switch'
  @echo '  just home news laercio@bigodon'
  @echo '  just home packages laercio@bigodon plasma'
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
homes:
  #!/usr/bin/env bash
  set -euo pipefail
  cd "{{flake_root}}"
  nix eval --json .#homeConfigurations --apply builtins.attrNames | jq -r '.[]'

[group("info")]
whoami:
  @echo "host: $(hostname)"
  @echo "usuário: $(whoami)"
  @echo "flake: {{flake_root}}"

[group("system")]
system action='switch' host='' desktop='gnome' *args:
  #!/usr/bin/env bash
  set -euo pipefail

  action="{{action}}"

  case "$action" in
    switch|boot|test|build|diff)
      nix run nixpkgs#just -- --justfile "{{justfile_file}}" _run_system "$action" "{{host}}" "{{desktop}}" {{args}}
      ;;
    switch-full)
      nix run nixpkgs#just -- --justfile "{{justfile_file}}" system switch "{{host}}" "{{desktop}}" {{args}}
      nix run nixpkgs#just -- --justfile "{{justfile_file}}" check
      ;;
    upgrade)
      nix run nixpkgs#just -- --justfile "{{justfile_file}}" update
      nix run nixpkgs#just -- --justfile "{{justfile_file}}" system switch "{{host}}" "{{desktop}}" {{args}}
      ;;
    *)
      echo "Ação de sistema inválida: '$action'" >&2
      echo "Use: switch, switch-full, boot, test, build, diff ou upgrade." >&2
      exit 1
      ;;
  esac

[group("home")]
home action='switch' target='' desktop='' *args:
  #!/usr/bin/env bash
  set -euo pipefail

  action="{{action}}"

  case "$action" in
    switch|news|packages)
      nix run nixpkgs#just -- --justfile "{{justfile_file}}" _run_home "$action" "{{target}}" "{{desktop}}" {{args}}
      ;;
    *)
      echo "Ação de home inválida: '$action'" >&2
      echo "Use: switch, news ou packages." >&2
      exit 1
      ;;
  esac

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
