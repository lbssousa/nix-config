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
      echo "  switch [host]        Rebuild e ativa a configuração (padrão: host atual)"
      echo "  boot   [host]        Rebuild e define para o próximo boot"
      echo "  test   [host]        Rebuild e testa (não define como padrão)"
      echo "  build  [host]        Apenas constrói sem ativar"
      echo ""
      echo "Comandos de home-manager (sem sudo):"
      echo "  home [user[@host]]   Aplica configuração Home Manager do usuário"
      echo "                       Padrão: usuário atual no host atual"
      echo "  news [user[@host]]   Exibe notícias do Home Manager desde a última versão"
      echo "                       Padrão: usuário atual no host atual"
      echo ""
      echo "Manutenção:"
      echo "  update [input...]    Atualiza inputs do flake (todos ou específicos)"
      echo "  gc [full|<período>]  Coleta lixo do store Nix (padrão: --delete-older-than 30d)"
      echo "  check                Verifica o flake (nix flake check)"
      echo "  fmt                  Formata todos os arquivos .nix com nixfmt"
      echo ""
      echo "Informações:"
      echo "  diff [host]          Mostra diff entre geração atual e a nova"
      echo ""
      echo "Variáveis de ambiente:"
      echo "  LBNIX_FLAKE_DIR      Caminho para o flake (padrão: /etc/nixos)"
    }

    _rebuild() {
      local subcmd="$1"
      local host="''${2:-$HOST}"
      if [ "$#" -ge 2 ]; then
        shift 2
      else
        shift "$#"
      fi
      nixos-rebuild "$subcmd" --flake "$FLAKE_DIR#$host" "$@"
    }

    case "''${1:-}" in
      switch|boot|test|build)
        _rebuild "$@"
        ;;
      home)
        # home-manager switch para um usuário@host
        # Uso: lbnix home [user[@host]]
        # Padrão: usuário atual no host atual
        _target="''${2:-$(whoami)@$HOST}"
        # Se apenas o usuário foi fornecido (sem @host), adiciona o host atual
        if [[ "''${_target}" != *@* ]]; then
          _target="''${_target}@''${HOST}"
        fi
        home-manager switch --flake "''${FLAKE_DIR}#''${_target}" "''${@:3}"
        ;;
      news)
        # home-manager news para um usuário@host
        # Uso: lbnix news [user[@host]]
        # Padrão: usuário atual no host atual
        _target="''${2:-$(whoami)@$HOST}"
        if [[ "''${_target}" != *@* ]]; then
          _target="''${_target}@''${HOST}"
        fi
        home-manager news --flake "''${FLAKE_DIR}#''${_target}" "''${@:3}"
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
        host="''${2:-$HOST}"
        new_drv="$(
          nix build \
            "$FLAKE_DIR#nixosConfigurations.''${host}.config.system.build.toplevel" \
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
