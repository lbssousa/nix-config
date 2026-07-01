# Módulo de containers: Podman rootless + Distrobox
# Experiência similar ao Fedora Silverblue
{ pkgs, ... }:

{
  # Habilitar subsistema de containers
  virtualisation.containers = {
    enable = true;
  };

  # Podman - runtime de containers rootless
  virtualisation.podman = {
    enable = true;
    # Alias 'docker' para compatibilidade
    dockerCompat = true;
    # DNS para comunicação entre containers em compose
    defaultNetwork.settings.dns_enabled = true;
    # Autocleanup de containers parados
    autoPrune = {
      enable = true;
      dates = "weekly";
      flags = [ "--all" ];
    };
  };

  # Distrobox - execute qualquer distro Linux em containers rootless
  environment.systemPackages = with pkgs; [
    distrobox
    podman-compose
    podman-tui
  ];

  # Habilitar suporte a user namespaces (necessário para rootless)
  security.unprivilegedUsernsClone = true;
}
