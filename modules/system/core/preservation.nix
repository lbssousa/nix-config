# Preservation module: ephemeral system with tmpfs on the root
# The root (/) is a tmpfs — automatically wiped on every boot, no rollback
# or snapshot needed. Important data is preserved in /persist via bind
# mounts managed by the nix-community/preservation module.
#
# /home has its own Btrfs subvolume (see disko.nix) and is not affected by
# the ephemeral root — user data persists there normally, with no need for
# per-item preservation bind mounts.
_:

{
  # Mark /persist and /home as needed at boot (preservation depends on this)
  fileSystems = {
    "/persist".neededForBoot = true;
    "/home".neededForBoot = true;
  };

  preservation.enable = true;

  preservation.preserveAt."/persist" = {
    directories = [
      # Symlinks: applications read via normal stat() and follow symlinks without restriction
      {
        directory = "/etc/nixos";
        how = "symlink";
      } # NixOS configuration
      {
        directory = "/etc/NetworkManager/system-connections";
        how = "symlink";
      } # Saved network connections
      {
        directory = "/var/lib/nixos";
        how = "symlink";
      } # NixOS internal state
      # Bind-mounts: applications use lstat() or have security restrictions
      "/var/lib/bluetooth" # Mandatory bind-mount: bluetoothd's StateDirectory= fails with a symlink on systemd 256+
      "/var/lib/fprint" # Same: fprintd uses StateDirectory=fprint with namespace isolation
      "/var/lib/systemd" # systemd state — sensitive to the directory itself
      "/var/db/sudo" # sudo timestamps — sudo uses lstat() for security
    ];

    files = [
      # inInitrd: machine-id is read by systemd-journald before any regular mount
      {
        file = "/etc/machine-id";
        inInitrd = true;
      } # Unique machine ID
      # NOTE: /etc/shadow is NOT managed here.
      # The users module (users.nix) defines a 'restoreShadow' activation
      # script with deps = ["users"] that, after NixOS's 'users' activation
      # script (which does an atomic rename of /etc/shadow), copies
      # /persist/etc/shadow → /etc/shadow. This ensures password changes
      # via 'passwd' are persisted to /persist/etc/shadow.
    ];
  };

  # /etc/machine-id is bind-mounted from btrfs (@persist) by preservation in
  # the initrd. systemd-machine-id-commit.service is meant to "commit" a
  # transient machine-id (initrd tmpfs) to disk — that doesn't apply here
  # since the file is already persistent. The
  # ConditionPathIsMountPoint=/etc/machine-id condition triggers the service
  # (since it IS a mount point), but --commit fails ("not on a temporary
  # file system"). The drop-in below inverts the condition to suppress the run.
  systemd.services."systemd-machine-id-commit" = {
    overrideStrategy = "asDropin";
    unitConfig = {
      ConditionPathIsMountPoint = [
        ""
        "!/etc/machine-id"
      ];
    };
  };
}
