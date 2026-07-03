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

    # Preservação do estado do Claude CLI entre reboots.
    # Credenciais (.credentials.json), configurações e memórias de projeto
    # ficam em ~/.claude — sem isso, o login é perdido a cada reboot (/ é tmpfs).
    preservation.preserveAt."/persist".users.abutre.directories = [
      ".claude"
    ];

    # Preservação da configuração de monitor (fator de escala, resolução, etc.).
    # monitors.xml é gerenciado pelo GNOME e precisa ser persistido para que
    # ajustes como fator de escala 100% sobrevivam ao reboot (/ e /home são tmpfs).
    preservation.preserveAt."/persist".users.abutre.files = [
      ".config/monitors.xml"
    ];

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
