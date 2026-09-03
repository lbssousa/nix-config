# Noctalia flake-parts module: adds the Noctalia suite (Umbriel compositor,
# Noctalia Shell, Noctalia Greeter) to the sharedModules of all hosts.
# Replaces GNOME entirely — see dendritic/flake/gnome-wrapper.nix (removed).
{ inputs, ... }:
{
  config = {
    dendritic.nixos.sharedModules = [
      inputs.umbriel.nixosModules.default
      inputs.noctalia.nixosModules.default
      inputs.noctalia-greeter.nixosModules.default

      (
        { pkgs, ... }:
        {
          programs = {
            # ── Compositor: Umbriel (independent wlroots compositor) ────────
            # Registers the "Umbriel" Wayland session and its xdg-desktop-portal
            # backend (screencast/screenshot/file-chooser via
            # xdg-desktop-portal-umbriel, falling back to gtk).
            umbriel.enable = true;

            # ── Shell: Noctalia (bars, launcher, dock, notifications, OSDs,
            # lock screen, session actions — no Qt/GTK dependency) ──────────
            noctalia = {
              enable = true;
              # Pulls in NetworkManager, Bluetooth, UPower and
              # power-profiles-daemon: the services Noctalia's quick settings
              # and OSDs expect to talk to.
              recommendedServices.enable = true;
            };

            # ── Greeter: Noctalia Greeter (replaces GDM) ─────────────────────
            noctalia-greeter = {
              enable = true;
              settings = {
                session.default = "Umbriel";
                appearance = {
                  scheme = "Catppuccin";
                  theme_mode = "dark";
                };
                # br+abnt2 layout for the login screen.
                # Mirrors services.xserver.xkb defined in localization.nix.
                keyboard = {
                  layout = "br";
                  variant = "abnt2";
                };
              };
            };
          };

          services = {
            # Flatpak — apps with no nixpkgs equivalent, installed declaratively.
            flatpak = {
              enable = true;
              packages = [
                "com.bitwarden.desktop" # Password manager
                "com.github.tchx84.Flatseal" # Flatpak permissions manager
                "com.ranfdev.DistroShelf" # Container distro manager
                "io.github.flattool.Ignition" # Flatpak autostart manager
                "io.github.flattool.Warehouse" # Flatpak app manager
                "org.mozilla.firefox" # Default browser
                "com.brave.Browser" # Alternate browser / PWAs
                "us.zoom.Zoom" # Video conferencing
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
            systemPackages = with pkgs; [
              # Default terminal
              ghostty

              # PGP/X.509 key management
              seahorse

              # Content creation
              obs-studio
              pinta

              # System utility (ISO flashing) — no Noctalia/Umbriel equivalent
              impression

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

          # Creates ~/.config/ibus/Compose for all users on session start.
          # The 'f' directive only creates the file if it doesn't already exist.
          # The 'd' rule ensures the parent directory exists (including for the greeter).
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
