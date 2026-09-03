# Homebrew (Linuxbrew), available to every user similarly to Flatpak: a
# shared prefix (pre-created with the right ownership by
# modules/system/tools/homebrew.nix) bootstrapped and kept in sync with a
# declarative Brewfile — the Homebrew analogue of services.flatpak.packages.
#
# Homebrew's official installer refuses to run as root, so this all runs as
# a systemd --user service instead of the system-level service Flatpak uses.
{ pkgs, ... }:
{
  home = {
    sessionPath = [
      "/home/linuxbrew/.linuxbrew/bin"
      "/home/linuxbrew/.linuxbrew/sbin"
    ];

    sessionVariables = {
      HOMEBREW_PREFIX = "/home/linuxbrew/.linuxbrew";
      HOMEBREW_CELLAR = "/home/linuxbrew/.linuxbrew/Cellar";
      HOMEBREW_REPOSITORY = "/home/linuxbrew/.linuxbrew/Homebrew";
    };

    file.".local/bin/homebrew-managed-install" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        set -euo pipefail

        export PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$PATH"

        if [ ! -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
          # NixOS has no /bin/bash (only /bin/sh) — the official installer's
          # documented "/bin/bash -c ..." invocation doesn't exist here,
          # which made this fail with "127" (command not found). Use the
          # store path instead.
          NONINTERACTIVE=1 ${pkgs.bash}/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi

        brew tap ublue-os/homebrew-tap
        brew trust ublue-os/homebrew-tap || true
        brew bundle install --file="$HOME/.config/homebrew/Brewfile"
      '';
    };
  };

  xdg.configFile."homebrew/Brewfile".text = ''
    tap "ublue-os/homebrew-tap"

    # TUI for managing Homebrew (formulae, casks, Flatpak, Mac App Store)
    brew "bbrew"

    # Editors — swapped from their Nix-installed equivalents: Homebrew
    # tracks upstream releases much faster, and for VS Code specifically
    # ships a genuinely FHS-compliant build instead of patching around it
    # (see the removed vscode-fhs in modules/system/desktop/desktop.nix).
    cask "ublue-os/tap/visual-studio-code-linux"

    # AI CLIs — swapped from their Nix-installed equivalents (claude-code,
    # github-copilot-cli, opencode in users/abutre.nix): these update very
    # frequently upstream, which Homebrew's rolling formulae track much
    # better than nixpkgs' release cadence.
    cask "claude-code"
    cask "copilot-cli"
    brew "opencode"
  '';

  systemd.user.services.homebrew-managed-install = {
    Unit = {
      Description = "Bootstrap Homebrew and apply the declarative Brewfile";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };

    Service = {
      Type = "oneshot";
      # /home/linuxbrew/.linuxbrew is pre-created (owned by root:linuxbrew,
      # group-writable) by modules/system/tools/homebrew.nix — the official
      # installer checks whether its prefix is already writable before
      # asking for sudo access, so this never prompts for a password.
      ExecStart = "%h/.local/bin/homebrew-managed-install";
    };

    Install.WantedBy = [ "default.target" ];
  };
}
