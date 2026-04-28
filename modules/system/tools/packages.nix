# Módulo de pacotes: Ferramentas essenciais do sistema
{ pkgs, inputs, ... }:

{
  environment.systemPackages =
    with pkgs;
    [
      # Ferramentas básicas do sistema
      git
      wget
      curl
      htop
      btop
      pciutils
      usbutils
      lshw
      file
      tree
      ripgrep
      fd
      bat
      jq
      unzip
      zip
      p7zip

      # Editores de texto para console
      neovim # Editor padrão
      helix # Editor alternativo moderno

      # Ferramentas de rede
      nmap
      dig
      traceroute
      iperf3

      # Monitoramento
      lm_sensors
      nvtopPackages.full # Monitor de GPU

      # Utilitários do sistema
      gptfdisk
      parted
      e2fsprogs # fornece chattr
      cryptsetup
      lvm2
      zfs
    ]
    ++ [
      # Home Manager (da mesma versão do flake) — CLI para switches independentes do sistema
      # Uso: home-manager switch --flake /etc/nixos#<usuario>@<host>
      inputs.home-manager.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];

  # Definir Neovim como editor padrão do sistema
  environment.variables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  # Alias para compatibilidade
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    vimAlias = true;
    viAlias = true;
  };
}
