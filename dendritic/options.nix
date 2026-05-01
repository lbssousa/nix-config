{ lib, ... }:
{
  options.dendritic = {
    hosts = lib.mkOption {
      description = "Inventario de hosts para gerar saidas NixOS e Disko.";
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            system = lib.mkOption {
              type = lib.types.str;
              description = "Sistema da arquitetura do host.";
            };

            defaultDesktop = lib.mkOption {
              type = lib.types.enum [ "gnome" "plasma" ];
              description = "Desktop padrao para a saida canonica sem sufixo.";
            };

            extraNixosModules = lib.mkOption {
              type = lib.types.listOf lib.types.deferredModule;
              default = [ ];
              description = "Modulos extras por host (ex.: lanzaboote).";
            };
          };
        }
      );
      default = { };
    };

    users = lib.mkOption {
      description = "Usuarios gerenciados pelo Home Manager standalone.";
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };

    desktops = lib.mkOption {
      description = "Ambientes desktop suportados para variantes de saida.";
      type = lib.types.listOf (lib.types.enum [ "gnome" "plasma" ]);
      default = [ "gnome" "plasma" ];
    };

    localOverlay = lib.mkOption {
      description = "Overlay local com pacotes fora do nixpkgs oficial.";
      type = lib.types.functionTo (lib.types.functionTo lib.types.attrs);
      default = _final: _prev: { };
    };

    nixos = {
      sharedModules = lib.mkOption {
        description = "Modulos NixOS compartilhados por todos os hosts.";
        type = lib.types.listOf lib.types.deferredModule;
        default = [ ];
      };

      userModules = lib.mkOption {
        description = "Modulos NixOS de contas de usuario aplicados a todos os hosts.";
        type = lib.types.listOf lib.types.deferredModule;
        default = [ ];
      };
    };
  };
}
