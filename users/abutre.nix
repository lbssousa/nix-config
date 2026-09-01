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

    # Note: dock shortcuts (formerly the GNOME Shell favorites bar) are
    # declared per-user via programs.noctalia.settings.dock.pinned in
    # home/users/abutre/noctalia.nix — Noctalia's config lives in ~/.config
    # (a persistent Btrfs subvolume), so no system-level dconf workaround is
    # needed the way GNOME's ephemeral-home dconf database required.

    # Packages specific to the abutre user, installed via NixOS.
    # Development tools and apps exclusive to this user.
    # Note: claude-code, github-copilot-cli and opencode moved to Homebrew
    # ("claude-code"/"copilot-cli" casks, "opencode" formula — see
    # modules/home/apps/homebrew.nix): all three update very frequently
    # upstream, better tracked by Homebrew's rolling formulae than nixpkgs'
    # release cadence.
    users.users.abutre.packages = with pkgs; [
      # Development
      gcc
      grelint # Linter for GABC/Gregorio (local overlay)
      python3
      rustup
      pandoc

      # Proprietary browser (in addition to Firefox, Brave and Chrome in systemPackages)
      microsoft-edge
    ];
  }
]
