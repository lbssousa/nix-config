# Módulo flake-parts do GNOME: adiciona a configuração NixOS específica do
# GNOME ao sharedModules de todos os hosts.
_: {
  config = {
    # ── Módulo NixOS do GNOME: contribui ao sharedModules de todos os hosts ───
    dendritic.nixos.sharedModules = [
      (
        {
          pkgs,
          lib,
          ...
        }:
        {
          services = {
            # Sessão GNOME (Wayland — padrão e único modo suportado no GNOME 50+)
            displayManager.gdm.enable = true;
            desktopManager.gnome = {
              enable = true;
              # Expõe o schema org.gnome.login-screen (fornecido pelo GDM) na
              # sessão do usuário. Sem isso, GNOME Settings não encontra o schema
              # ao verificar `enable-fingerprint-authentication`, e a linha de
              # impressão digital fica oculta em Configurações → Sistema → Usuários.
              # O módulo NixOS do GNOME exporta schemas via sessionPath; o GDM não
              # está no sessionPath padrão, por isso precisa ser adicionado
              # explicitamente.
              sessionPath = [ pkgs.gdm ];
            };

            # Flatpak — apps sem equivalente no nixpkgs instalados declarativamente.
            flatpak = {
              enable = true;
              packages = [
                "com.bitwarden.desktop" # Gestão de senhas
                "com.github.tchx84.Flatseal" # Gerenciador de permissões Flatpak
                "com.ranfdev.DistroShelf" # Gerenciador de distros em contêineres
                "io.github.flattool.Ignition" # Gerenciador de autostart de Flatpaks
                "io.github.flattool.Warehouse" # Gerenciador de apps Flatpak
                "io.github.kolunmi.Bazaar" # Loja de apps GNOME
                "org.mozilla.firefox" # Navegador padrão
                "com.brave.Browser" # Navegador alternativo / PWAs
              ];
              update.onActivation = true;
              update.auto = {
                enable = true;
                onCalendar = "daily";
              };
            };

            # Impressão (CUPS)
            printing.enable = true;
          };

          environment = {
            gnome.excludePackages = with pkgs; [
              # Tour de boas-vindas — sem substituto
              gnome-tour
              # Terminais GNOME nativos — substituídos pelo Ghostty
              gnome-console
              gnome-terminal
              ptyxis
              # Gerenciador de software — gerenciamento de pacotes é feito pelo Nix
              gnome-software
              # Ajuda GNOME — sem substituto relevante
              yelp
            ];

            systemPackages = with pkgs; [
              # Terminal padrão
              ghostty

              # Gestão de chaves PGP/X.509
              seahorse

              # Criação de conteúdo
              obs-studio
              pinta

              # Utilitários de sistema e produtividade
              gnome-extension-manager
              impression
              smile
              zoom-us

              # Tema GTK3 para compatibilidade com apps legados
              adw-gtk3
            ];

            etc = {
              # Padrão de sistema: Firefox como fallback para usuários sem
              # preferência configurada no Home Manager.
              "xdg/mimeapps.list".text = ''
                [Default Applications]
                text/html=org.mozilla.firefox.desktop
                x-scheme-handler/http=org.mozilla.firefox.desktop
                x-scheme-handler/https=org.mozilla.firefox.desktop
                x-scheme-handler/about=org.mozilla.firefox.desktop
                x-scheme-handler/unknown=org.mozilla.firefox.desktop
              '';
            };
          };

          programs.dconf = {
            enable = true;
            # Layout br+abnt2 como default para todos os usuários.
            # Espelha services.xserver.xkb definido em localization.nix no lado GNOME:
            # sem isso, o GNOME ignora o XKB do sistema e exibe apenas "English (US)".
            # profiles.user.databases: banco dconf de sistema, gravado em /etc/dconf/db/
            # e independente do home. Use aqui (não em dconf.settings no HM) para
            # qualquer setting que deva sobreviver a reboots com home efêmero.
            profiles.user.databases = [
              {
                settings = {
                  "org/gnome/shell" = {
                    enabled-extensions = [
                      "appindicatorsupport@rgcjonas.gmail.com"
                      "caffeine@patapon.info"
                      "quake-terminal@diegodario88.github.io"
                    ];
                  };

                  # Layout br+abnt2 para todos os usuários.
                  # Espelha services.xserver.xkb definido em localization.nix.
                  "org/gnome/desktop/input-sources" = {
                    sources = [
                      (lib.gvariant.mkTuple [
                        "xkb"
                        "br"
                      ])
                    ];
                  };

                  # Quake Terminal — perfil sem decorações definido em ghostty.nix
                  "org/gnome/shell/extensions/quake-terminal" = {
                    terminal-id = "ghostty-no-decorations.desktop";
                    terminal-shortcut = [ "F12" ];
                    vertical-size = lib.gvariant.mkInt32 75;
                    skip-taskbar = true;
                  };
                };
              }
            ];
          };

          # Cria ~/.config/ibus/Compose para todos os usuários ao iniciar a sessão.
          # A diretiva 'f' só cria o arquivo se ainda não existir.
          # A regra 'd' garante que o diretório pai exista (inclusive para gdm-greeter).
          systemd.user.tmpfiles.rules = [
            "d %h/.config/ibus 0755 - - -"
            ''f %h/.config/ibus/Compose 0644 - - - include "%%L"''
          ];

          # Aguardar conectividade antes de instalar/atualizar Flatpaks.
          systemd.services.flatpak-managed-install = {
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
          };

          # Regra Polkit para permitir instalação de Flatpaks system-wide sem senha.
          security.polkit.extraConfig = ''
            // Permitir que usuários do grupo 'wheel' gerenciem Flatpaks sem senha
            polkit.addRule(function(action, subject) {
              if (action.id.indexOf("org.freedesktop.Flatpak") === 0 &&
                  subject.isInGroup("wheel")) {
                return polkit.Result.YES;
              }
            });
          '';
        }
      )
    ];
  };
}
