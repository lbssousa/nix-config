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

    # Atalhos da dock (barra de favoritos do GNOME Shell) para o usuário abutre.
    # Declarado via programs.dconf.profiles.user.databases (banco dconf de sistema,
    # em /etc/dconf/db/) para sobreviver ao reboot com home efêmero.
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

    # Pacotes específicos do usuário abutre instalados via NixOS.
    # Ferramentas de desenvolvimento e apps exclusivos deste usuário.
    users.users.abutre.packages = with pkgs; [
      # Desenvolvimento
      claude-code
      github-copilot-cli
      gcc
      grelint # Linter para GABC/Gregório (overlay local)
      python3
      rustup
      opencode
      pandoc

      # Browser proprietário (além de Firefox, Brave e Chrome em systemPackages)
      microsoft-edge
    ];
  }
]
