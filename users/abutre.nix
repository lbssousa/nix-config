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
