{
  pkgs,
  lib,
  ...
}:
lib.mkMerge [
  (import ./mkUser.nix { inherit pkgs lib; } {
    username = "abutre";
    uid = 1000;
    hasSudo = true;
  })

  {
    security.keepassxc.autoLockOnYubikeyRemove.users = [ "abutre" ];

    # Dock shortcuts (GNOME Shell favorites bar) for the abutre user.
    # Declared via programs.dconf.profiles.user.databases (system dconf
    # database, in /etc/dconf/db/) to survive reboots with an ephemeral home.
    programs.dconf.profiles.user.databases = [
      {
        settings = {
          "org/gnome/shell" = {
            favorite-apps = [
              "org.mozilla.firefox.desktop"
              "com.brave.Browser.desktop"
              "org.gnome.TextEditor.desktop"
              "org.gnome.Nautilus.desktop"
              "io.github.kolunmi.Bazaar.desktop"
              "code.desktop"
              "dev.zed.Zed.desktop"
            ];
          };
        };
      }
    ];

    # Packages specific to the abutre user, installed via NixOS.
    # Development tools and apps exclusive to this user.
    users.users.abutre.packages = with pkgs; [
      # Development
      claude-code
      github-copilot-cli
      gcc
      grelint # Linter for GABC/Gregorio (local overlay)
      python3
      rustup
      opencode
      pandoc

      # Proprietary browser (in addition to Firefox, Brave and Chrome in systemPackages)
      microsoft-edge
    ];
  }
]
