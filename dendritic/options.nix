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

            extraNixosModules = lib.mkOption {
              type = lib.types.listOf lib.types.deferredModule;
              default = [ ];
              description = "Modulos extras por host.";
            };
          };
        }
      );
      default = { };
    };

    users = lib.mkOption {
      description = "Usuarios do sistema, com Home Manager gerenciado como modulo NixOS.";
      type = lib.types.listOf lib.types.str;
      default = [ ];
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
