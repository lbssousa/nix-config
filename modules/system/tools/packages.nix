# Packages module: essential system tools
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
    # Basic system tools
    git
    git-crypt
    wget
    curl
    htop
    btop
    gh # GitHub CLI
    glab # GitLab CLI
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

    # Console text editors
    neovim # Default editor
    helix # Modern alternate editor

    # Network tools
    nmap
    dig
    traceroute
    iperf3

    # Monitoring
    lm_sensors
    nvtopPackages.full # GPU monitor

    # System utilities
    gptfdisk
    parted
    e2fsprogs # provides chattr
    cryptsetup
    lvm2
    zfs

    # GStreamer and multimedia packages (useful for browsers and GNOME apps)
    gst_all_1.gst-libav
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-ugly
    gst_all_1.gst-vaapi
    ffmpeg
    libva # VA-API library + vainfo diagnostic utility
  ];

  # Set Neovim as the system's default editor
  environment.variables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  # Alias for compatibility
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    vimAlias = true;
    viAlias = true;
  };
}
