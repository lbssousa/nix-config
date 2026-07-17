# Helper function to create NixOS user definitions
# Usage: import ./mkUser.nix { inherit pkgs lib; } { username = ...; ... }
#
# NOTE: Home Manager configuration is managed as a NixOS module
# (home-manager.users.<name> in dendritic/flake/home-nixos-module.nix). See
# home/users/<user>/home.nix for per-user customizations.
#
# NOTE: The full name (description) is set via the nix-secrets flake outputs
# (inputs.nix-secrets.${username}.fullName). It must not be set here.
{ pkgs, lib }:
{
  username,
  # Fixed numeric UID. ALWAYS set it to avoid reassignment after
  # adding/removing users, which would cause ownership mismatches on $HOME files.
  uid ? null,
  # Whether the user belongs to the "wheel" group (sudo). Default: false.
  hasSudo ? false,
}:

{
  # Creates a group with the same name as the user (needed by applications
  # that call `chown username:username`, like epson-printer-utility).
  users.groups.${username} = { };

  users.users.${username} = {
    isNormalUser = true;
  }
  // lib.optionalAttrs (uid != null) { inherit uid; }
  // {
    # Groups essential for a GNOME + containers desktop
    extraGroups = [
      "networkmanager" # Manage network connections
      "video" # GPU access
      "audio" # Audio access
      "plugdev" # USB device access
      "dialout" # Serial ports
      "docker" # Docker compatibility (Podman)
    ]
    ++ lib.optionals hasSudo [
      "wheel" # sudo
    ];
    shell = pkgs.fish; # Default shell (Fish)
    # Initial password: the user will be prompted to change it on first login.
    # If a custom password is set during installation (see INSTALLATION.md),
    # the change won't be required.
    initialPassword = "nixos";
  };

  # ─────────────────────────────────────────────────────────────────────────
  # Selective preservation of the home directory
  # ─────────────────────────────────────────────────────────────────────────
  #
  # /home is tmpfs — ephemeral on every boot. The preservation module
  # bind-mounts the items below from /persist/home/<user>/ into the user's
  # home directory. Anything not listed here is recreated by Home Manager
  # or discarded.
  #
  # NOTE: the directory names below match the actual on-disk XDG user
  # directories, which are named in Portuguese because the system locale is
  # pt_BR (see modules/system/core/localization.nix). Do not translate
  # these strings — they must match the real folder names or the
  # corresponding user data won't be preserved across reboots.
  #
  # To migrate an existing install:
  #   run0 rsync -a /home/<user>/Documentos/ /persist/home/<user>/Documentos/
  #   (repeat for each directory listed below)
  preservation.preserveAt."/persist".users.${username} = {
    directories = [
      # ── Default XDG directories (user data) ───────────────────────────
      # Symlinks: plain data, no special path checks
      {
        directory = "Área de Trabalho";
        how = "symlink";
      }
      {
        directory = "Documentos";
        how = "symlink";
      }
      {
        directory = "Downloads";
        how = "symlink";
      }
      {
        directory = "Imagens";
        how = "symlink";
      }
      {
        directory = "Modelos";
        how = "symlink";
      }
      {
        directory = "Músicas";
        how = "symlink";
      }
      {
        directory = "Projetos";
        how = "symlink";
      }
      {
        directory = "Público";
        how = "symlink";
      }
      {
        directory = "Vídeos";
        how = "symlink";
      }

      # ── Identity and security ───────────────────────────────────────────
      # Bind-mounts: SSH (StrictModes uses lstat) and GPG (2.x does a security lstat)
      ".ssh" # SSH keys, known_hosts, authorized_keys
      ".gnupg" # GPG keys, trust database, YubiKey stubs

      # ── Browsers (nixpkgs packages — data not managed by HM) ────────────
      # Note: .mozilla is not preserved — Firefox now runs via Flatpak,
      # whose data lives in .var/app (preserved below).
      # Bind-mount: Chromium's sandbox checks the directory's real ownership
      {
        directory = ".config/BraveSoftware";
        mode = "0700"; # Brave stores credentials here
      }

      # ── Flatpak: per-application data ────────────────────────────────────
      {
        directory = ".var/app";
        how = "symlink";
      } # Bitwarden vault, data for all Flatpaks
      {
        directory = ".config/autostart";
        how = "symlink";
      } # Flatpak autostart (managed by Ignition)

      # ── GNOME / desktop state ────────────────────────────────────────────
      # Note: .config/dconf is intentionally NOT preserved.
      # dconf settings that must survive reboot should be declared via
      # programs.dconf.profiles.*.databases in NixOS (written to /etc/dconf/,
      # which is system-managed and independent of the home). Home Manager's
      # dconf.settings only writes to ~/.config/dconf/user on activation —
      # don't use it for settings that must persist with an ephemeral home.
      {
        directory = ".local/share/keyrings";
        how = "symlink";
      } # GNOME keyring: Wi-Fi and app passwords
      {
        directory = ".local/share/applications";
        how = "symlink";
      } # User and Flatpak .desktop files

      # ── App config (not managed by HM) ───────────────────────────────────
      {
        directory = ".config/keepassxc";
        how = "symlink";
      } # Preferences and database path
      {
        directory = ".config/gh";
        how = "symlink";
        mode = "0700";
      } # GitHub CLI auth token (hosts.yml) and config

      # ── Shell tools ───────────────────────────────────────────────────────
      {
        directory = ".local/share/zoxide";
        how = "symlink";
      } # zoxide frequency database (smart cd)
      {
        directory = ".local/share/fish";
        how = "symlink";
      } # Fish history and function cache
      {
        directory = ".local/share/direnv";
        how = "symlink";
      } # direnv "allow" cache (avoids re-approving .envrc after every reboot)

      # ── Rootless containers (Podman without root) ────────────────────────
      # Bind-mount: bubblewrap/Podman checks that the path is a real directory
      ".local/share/containers" # User's Podman images and volumes

      # ── Claude CLI ──────────────────────────────────────────────────────
      # Credentials (.credentials.json), settings and project memories.
      # Without this, the login is lost on every reboot (/ is tmpfs).
      {
        directory = ".claude";
        how = "symlink";
      }
    ];

    files = [
      {
        file = ".bash_history";
        how = "symlink";
      }
      {
        file = ".zsh_history";
        how = "symlink";
      }
      {
        file = ".config/user-dirs.dirs";
        how = "symlink";
      }
      {
        file = ".config/user-dirs.locale";
        how = "symlink";
      }
      {
        file = ".claude.json";
        how = "symlink";
        mode = "0600";
      }
      # Monitor configuration (scale factor, resolution, etc.), managed by
      # GNOME. Needs to be persisted to survive reboots (/ and /home are tmpfs).
      {
        file = ".config/monitors.xml";
        how = "symlink";
      }
    ];
  };
}
