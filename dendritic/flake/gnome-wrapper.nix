# GNOME flake-parts module: adds GNOME-specific NixOS configuration to the
# sharedModules of all hosts.
_: {
  config = {
    # ── GNOME NixOS module: contributes to the sharedModules of all hosts ────
    dendritic.nixos.sharedModules = [
      (
        {
          pkgs,
          lib,
          ...
        }:
        {
          services = {
            # GNOME session (Wayland — the default and only supported mode in GNOME 50+)
            displayManager.gdm.enable = true;
            desktopManager.gnome = {
              enable = true;
              # Exposes the org.gnome.login-screen schema (provided by GDM) in the
              # user session. Without this, GNOME Settings can't find the schema
              # when checking `enable-fingerprint-authentication`, and the
              # fingerprint row stays hidden in Settings → System → Users.
              # The GNOME NixOS module exports schemas via sessionPath; GDM isn't
              # in the default sessionPath, so it needs to be added explicitly.
              sessionPath = [ pkgs.gdm ];
            };

            # Flatpak — apps with no nixpkgs equivalent, installed declaratively.
            flatpak = {
              enable = true;
              packages = [
                "com.bitwarden.desktop" # Password manager
                "com.github.tchx84.Flatseal" # Flatpak permissions manager
                "com.ranfdev.DistroShelf" # Container distro manager
                "io.github.flattool.Ignition" # Flatpak autostart manager
                "io.github.flattool.Warehouse" # Flatpak app manager
                "io.github.kolunmi.Bazaar" # GNOME app store
                "org.mozilla.firefox" # Default browser
                "com.brave.Browser" # Alternate browser / PWAs
              ];
              update.onActivation = true;
              update.auto = {
                enable = true;
                onCalendar = "daily";
              };
            };

            # Printing (CUPS)
            printing.enable = true;
          };

          environment = {
            gnome.excludePackages = with pkgs; [
              # Welcome tour — no replacement
              gnome-tour
              # Native GNOME terminals — replaced by Ghostty
              gnome-console
              gnome-terminal
              ptyxis
              # Software manager — package management is done by Nix
              gnome-software
              # GNOME Help — no relevant replacement
              yelp
            ];

            systemPackages = with pkgs; [
              # Default terminal
              ghostty

              # PGP/X.509 key management
              seahorse

              # Content creation
              obs-studio
              pinta

              # System utilities and productivity
              gnome-extension-manager
              impression
              smile
              zoom-us

              # GTK3 theme for compatibility with legacy apps
              adw-gtk3
            ];

            etc = {
              # System default: Firefox as the fallback for users with no
              # preference configured in Home Manager.
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
            # br+abnt2 layout as the default for all users.
            # Mirrors services.xserver.xkb defined in localization.nix on the GNOME
            # side: without this, GNOME ignores the system XKB and shows only
            # "English (US)".
            # profiles.user.databases: system-wide dconf database, written to
            # /etc/dconf/db/ and independent of the home. Use here (not
            # dconf.settings in HM) for any setting that must survive reboots
            # with an ephemeral home.
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

                  # br+abnt2 layout for all users.
                  # Mirrors services.xserver.xkb defined in localization.nix.
                  "org/gnome/desktop/input-sources" = {
                    sources = [
                      (lib.gvariant.mkTuple [
                        "xkb"
                        "br"
                      ])
                    ];
                  };

                  # Quake Terminal — desktop entry defined in ghostty.nix
                  # The ID uses --class=com.mitchellh.ghostty.quake so GNOME Shell
                  # assigns the window to the right Shell.App via the Wayland app_id.
                  "org/gnome/shell/extensions/quake-terminal" = {
                    terminal-id = "com.mitchellh.ghostty.quake.desktop";
                    terminal-shortcut = [ "F12" ];
                    vertical-size = lib.gvariant.mkInt32 75;
                    skip-taskbar = true;
                  };
                };
              }
            ];
          };

          # Creates ~/.config/ibus/Compose for all users on session start.
          # The 'f' directive only creates the file if it doesn't already exist.
          # The 'd' rule ensures the parent directory exists (including for gdm-greeter).
          systemd.user.tmpfiles.rules = [
            "d %h/.config/ibus 0755 - - -"
            ''f %h/.config/ibus/Compose 0644 - - - include "%%L"''
          ];

          # Wait for connectivity before installing/updating Flatpaks.
          systemd.services.flatpak-managed-install = {
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
          };

          # Polkit rule allowing system-wide Flatpak installs without a password.
          security.polkit.extraConfig = ''
            // Allow users in the 'wheel' group to manage Flatpaks without a password
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
