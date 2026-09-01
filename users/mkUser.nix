# Helper function to create NixOS user definitions
# Usage: import ./mkUser.nix { inherit pkgs lib; } { username = ...; ... }
#
# NOTE: Home Manager configuration is managed as a NixOS module
# (home-manager.users.<name> in dendritic/flake/home-nixos-module.nix), plus
# a standalone `home-manager switch --flake .#<user>@<host>` path
# (dendritic/flake/home-configurations.nix). See home/users/<user>/home.nix
# for per-user customizations — both paths share the same module.
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
    # Groups essential for the graphical desktop + containers
    extraGroups = [
      "networkmanager" # Manage network connections
      "video" # GPU access
      "audio" # Audio access
      "plugdev" # USB device access
      "dialout" # Serial ports
      "docker" # Docker compatibility (Podman)
      "linuxbrew" # Write access to the shared Homebrew prefix (see modules/system/tools/homebrew.nix)
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
}
