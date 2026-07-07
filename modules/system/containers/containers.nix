# Containers module: rootless Podman + Distrobox
# Fedora Silverblue-like experience
{ pkgs, ... }:

{
  # Enable the container subsystem
  virtualisation.containers = {
    enable = true;
  };

  # Podman - rootless container runtime
  virtualisation.podman = {
    enable = true;
    # 'docker' alias for compatibility
    dockerCompat = true;
    # DNS for inter-container communication in compose
    defaultNetwork.settings.dns_enabled = true;
    # Autocleanup of stopped containers
    autoPrune = {
      enable = true;
      dates = "weekly";
      flags = [ "--all" ];
    };
  };

  # Distrobox - run any Linux distro in rootless containers
  environment.systemPackages = with pkgs; [
    distrobox
    podman-compose
    podman-tui
  ];

  # Enable user namespace support (required for rootless)
  security.unprivilegedUsernsClone = true;
}
