# Módulo lbnix: wrapper para operações comuns do flake NixOS
#
# Instalado como 'lbnix' no PATH do sistema. Inspirado no comando 'phoenix'
# do projeto librephoenix/nixos-config e em iniciativas similares como
# Misterio77/dotfiles (Makefile) e outros wrappers de flake.
#
# Uso básico:
#   sudo lbnix switch          # rebuild + ativa configuração do host atual
#   lbnix home                 # home-manager switch do usuário atual no host atual
#   lbnix update               # atualiza todos os inputs do flake
#   lbnix gc                   # coleta lixo (padrão: entradas > 30 dias)
#   lbnix diff                 # mostra diff da geração atual para a nova
#   lbnix --help               # exibe ajuda completa
#
# Variáveis de ambiente:
#   LBNIX_FLAKE_DIR   Caminho para o diretório do flake (padrão: /etc/nixos)
{ pkgs, ... }:

let
  lbnix = pkgs.writeShellScriptBin "lbnix" ''
    set -euo pipefail

    FLAKE_DIR="''${LBNIX_FLAKE_DIR:-/etc/nixos}"
    HOST="$(hostname)"

    usage() {
      echo "lbnix — wrapper para operações comuns do flake NixOS"
      echo ""
      echo "Uso: lbnix <comando> [opções]"
      echo ""
      echo "Comandos de rebuild do sistema (requerem sudo):"
      echo "  switch [host|--host <host>] [--gnome|--plasma|--desktop <nome>]  Rebuild e ativa a configuração"
      echo "  boot   [host|--host <host>] [--gnome|--plasma|--desktop <nome>]  Rebuild e define para o próximo boot"
      echo "  test   [host|--host <host>] [--gnome|--plasma|--desktop <nome>]  Rebuild e testa (não define como padrão)"
      echo "  build  [host|--host <host>] [--gnome|--plasma|--desktop <nome>]  Apenas constrói sem ativar"
      echo "                       desktop padrão: gnome"
      echo ""
      echo "Comandos de home-manager (sem sudo):"
      echo "  home [user[@host]|--target <user[@host]>] [--gnome|--plasma|--desktop <nome>]   Aplica configuração Home Manager do usuário"
      echo "                       Padrão: usuário atual no host atual"
      echo "  news [user[@host]|--target <user[@host]>] [--gnome|--plasma|--desktop <nome>]   Exibe notícias do Home Manager desde a última versão"
      echo "                       Padrão: usuário atual no host atual"
      echo ""
      echo "Manutenção:"
      echo "  update [input...]    Atualiza inputs do flake (todos ou específicos)"
      echo "  gc [full|<período>]  Coleta lixo do store Nix (padrão: --delete-older-than 30d)"
      echo "  check                Verifica o flake (nix flake check)"
      echo "  fmt                  Formata todos os arquivos .nix com nixfmt"
      echo ""
      echo "Informações:"
      echo "  diff [host|--host <host>] [--gnome|--plasma|--desktop <nome>] Mostra diff entre geração atual e a nova"
      echo ""
      echo "Variáveis de ambiente:"
      echo "  LBNIX_FLAKE_DIR      Caminho para o flake (padrão: /etc/nixos)"
    }

    _flake_attr() {
      local host="$1"
      local desktop="''${2:-}"
      if [[ -z "$desktop" ]]; then
        echo "$host"
      elif [[ "$desktop" == "gnome" || "$desktop" == "plasma" ]]; then
        echo "''${host}-''${desktop}"
      else
        echo "Desktop inválido: '$desktop' (use gnome|plasma)" >&2
        exit 1
      fi
    }

    _parse_rebuild_args() {
      PARSED_DESKTOP="gnome"
      PARSED_HOST="$HOST"
      PARSED_FORWARD_ARGS=()
      local host_set=0

      while [[ "$#" -gt 0 ]]; do
        case "$1" in
          --gnome)
            PARSED_DESKTOP="gnome"
            shift
            ;;
          --plasma)
            PARSED_DESKTOP="plasma"
            shift
            ;;
          --desktop)
            if [[ "$#" -lt 2 ]]; then
              echo "Faltou valor para --desktop (use gnome|plasma)" >&2
              exit 1
            fi
            if [[ "$2" != "gnome" && "$2" != "plasma" ]]; then
              echo "Desktop inválido: '$2' (use gnome|plasma)" >&2
              exit 1
            fi
            PARSED_DESKTOP="$2"
            shift 2
            ;;
          --host)
            if [[ "$#" -lt 2 ]]; then
              echo "Faltou valor para --host" >&2
              exit 1
            fi
            PARSED_HOST="$2"
            host_set=1
            shift 2
            ;;
          --)
            shift
            PARSED_FORWARD_ARGS+=("$@")
            break
            ;;
          -*)
            PARSED_FORWARD_ARGS+=("$1")
            shift
            ;;
          *)
            if [[ "$host_set" -eq 0 ]]; then
              PARSED_HOST="$1"
              host_set=1
            else
              PARSED_FORWARD_ARGS+=("$1")
            fi
            shift
            ;;
        esac
      done
    }

    _parse_home_args() {
      PARSED_DESKTOP=""
      PARSED_TARGET="$(whoami)@$HOST"
      PARSED_FORWARD_ARGS=()
      local target_set=0

      while [[ "$#" -gt 0 ]]; do
        case "$1" in
          --gnome)
            PARSED_DESKTOP="gnome"
            shift
            ;;
          --plasma)
            PARSED_DESKTOP="plasma"
            shift
            ;;
          --desktop)
            if [[ "$#" -lt 2 ]]; then
              echo "Faltou valor para --desktop (use gnome|plasma)" >&2
              exit 1
            fi
            if [[ "$2" != "gnome" && "$2" != "plasma" ]]; then
              echo "Desktop inválido: '$2' (use gnome|plasma)" >&2
              exit 1
            fi
            PARSED_DESKTOP="$2"
            shift 2
            ;;
          --target)
            if [[ "$#" -lt 2 ]]; then
              echo "Faltou valor para --target" >&2
              exit 1
            fi
            PARSED_TARGET="$2"
            target_set=1
            shift 2
            ;;
          --)
            shift
            PARSED_FORWARD_ARGS+=("$@")
            break
            ;;
          -*)
            PARSED_FORWARD_ARGS+=("$1")
            shift
            ;;
          *)
            if [[ "$target_set" -eq 0 ]]; then
              PARSED_TARGET="$1"
              target_set=1
            else
              PARSED_FORWARD_ARGS+=("$1")
            fi
            shift
            ;;
        esac
      done
    }

    _rebuild() {
      local subcmd="$1"
      shift

      _parse_rebuild_args "$@"

      local host="$PARSED_HOST"
      local desktop="$PARSED_DESKTOP"
      local flake_attr

      flake_attr="$(_flake_attr "$host" "$desktop")"

      if [[ "''${#PARSED_FORWARD_ARGS[@]}" -gt 0 ]]; then
        nixos-rebuild "$subcmd" --flake "$FLAKE_DIR#$flake_attr" "''${PARSED_FORWARD_ARGS[@]}"
      else
        nixos-rebuild "$subcmd" --flake "$FLAKE_DIR#$flake_attr"
      fi
    }

    case "''${1:-}" in
      switch|boot|test|build)
        _rebuild "$@"
        ;;
      home)
        # home-manager switch para um usuário@host
        # Uso: lbnix home [user[@host]] [--gnome|--plasma|--desktop <nome>]
        # Padrão: usuário atual no host atual
        shift
        _parse_home_args "$@"
        _target="$PARSED_TARGET"
        _desktop="$PARSED_DESKTOP"
        # Se apenas o usuário foi fornecido (sem @host), adiciona o host atual
        if [[ "''${_target}" != *@* ]]; then
          _target="''${_target}@''${HOST}"
        fi
        if [[ -n "''${_desktop}" ]]; then
          _target="''${_target}-''${_desktop}"
        fi
        if [[ "''${#PARSED_FORWARD_ARGS[@]}" -gt 0 ]]; then
          home-manager switch --flake "''${FLAKE_DIR}#''${_target}" "''${PARSED_FORWARD_ARGS[@]}"
        else
          home-manager switch --flake "''${FLAKE_DIR}#''${_target}"
        fi
        ;;
      news)
        # home-manager news para um usuário@host
        # Uso: lbnix news [user[@host]] [--gnome|--plasma|--desktop <nome>]
        # Padrão: usuário atual no host atual
        shift
        _parse_home_args "$@"
        _target="$PARSED_TARGET"
        _desktop="$PARSED_DESKTOP"
        if [[ "''${_target}" != *@* ]]; then
          _target="''${_target}@''${HOST}"
        fi
        if [[ -n "''${_desktop}" ]]; then
          _target="''${_target}-''${_desktop}"
        fi
        if [[ "''${#PARSED_FORWARD_ARGS[@]}" -gt 0 ]]; then
          home-manager news --flake "''${FLAKE_DIR}#''${_target}" "''${PARSED_FORWARD_ARGS[@]}"
        else
          home-manager news --flake "''${FLAKE_DIR}#''${_target}"
        fi
        ;;
      update)
        pushd "$FLAKE_DIR" > /dev/null
        nix flake update "''${@:2}"
        popd > /dev/null
        ;;
      gc)
        case "''${2:-}" in
          full)
            nix-collect-garbage --delete-old
            ;;
          "")
            nix-collect-garbage --delete-older-than 30d
            ;;
          *)
            nix-collect-garbage --delete-older-than "''${2}"
            ;;
        esac
        ;;
      check)
        pushd "$FLAKE_DIR" > /dev/null
        nix flake check "''${@:2}"
        popd > /dev/null
        ;;
      fmt)
        pushd "$FLAKE_DIR" > /dev/null
        ${pkgs.nixfmt}/bin/nixfmt .
        popd > /dev/null
        ;;
      diff)
        shift
        _parse_rebuild_args "$@"
        host="$PARSED_HOST"
        desktop="$PARSED_DESKTOP"
        flake_attr="$(_flake_attr "$host" "$desktop")"
        new_drv="$(
          nix build \
            "$FLAKE_DIR#nixosConfigurations.''${flake_attr}.config.system.build.toplevel" \
            --no-link --print-out-paths 2>/dev/null
        )"
        ${pkgs.nvd}/bin/nvd diff /run/current-system "$new_drv"
        ;;
      --help|-h|help|"")
        usage
        ;;
      *)
        echo "lbnix: comando desconhecido: ''${1}" >&2
        echo "" >&2
        usage >&2
        exit 1
        ;;
    esac
  '';
in
{
  environment.systemPackages = [ lbnix ];
}
