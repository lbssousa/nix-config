# Módulo de pacotes: Ferramentas essenciais do sistema
{ pkgs, ... }:

let
  justWrapper = pkgs.writeShellApplication {
    name = "just";
    text = ''
      set -euo pipefail

      real_just=${pkgs.just}/bin/just
      fallback_justfile=/etc/nixos/justfile
      search_dir=$PWD
      explicit_justfile=false
      previous_arg=""

      for arg in "$@"; do
        case "$previous_arg" in
          --justfile|-f)
            explicit_justfile=true
            break
            ;;
          --working-directory|-d)
            search_dir=$arg
            previous_arg=""
            continue
            ;;
        esac

        case "$arg" in
          --justfile=*|-f=*)
            explicit_justfile=true
            break
            ;;
          --working-directory=*|-d=*)
            search_dir=''${arg#*=}
            ;;
        esac

        previous_arg=$arg
      done

      if [ "$explicit_justfile" = true ]; then
        exec "$real_just" "$@"
      fi

      case "$search_dir" in
        /*) ;;
        *) search_dir="$PWD/$search_dir" ;;
      esac

      if [ -d "$search_dir" ]; then
        while :; do
          for candidate in justfile .justfile Justfile; do
            if [ -f "$search_dir/$candidate" ]; then
              exec "$real_just" "$@"
            fi
          done

          if [ "$search_dir" = "/" ]; then
            break
          fi

          search_dir=''${search_dir%/*}
          if [ -z "$search_dir" ]; then
            search_dir=/
          fi
        done
      fi

      exec "$real_just" --justfile "$fallback_justfile" "$@"
    '';
  };
in
{
  environment.systemPackages = with pkgs; [
    # Ferramentas básicas do sistema
    git
    git-crypt
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
    justWrapper
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

    # Pacotes GStreamer e multimédia (úteis para navegadores)
    gst_all_1.gst-libav
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-ugly
    gst_all_1.gst-vaapi
    ffmpeg
    libva
    # Drivers VA-API (Intel/NVIDIA)
    intel-media-driver
    intel-vaapi-driver
    nvidia-vaapi-driver
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
