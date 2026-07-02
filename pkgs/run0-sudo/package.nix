{ writeShellApplication }:

writeShellApplication {
  name = "run0-sudo";

  text = ''
    RUN0=$(command -v run0) || { echo "run0 não encontrado (systemd v256+?)" >&2; exit 1; }

    AUTO_KEEP=(
      PATH HOME USER LOGNAME
      DISPLAY WAYLAND_DISPLAY XDG_SESSION_TYPE XDG_SESSION_ID
      XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS
      SSH_AUTH_SOCK SSH_AGENT_PID
      LANG LANGUAGE LC_ALL LC_MESSAGES
      EDITOR VISUAL PAGER TERM COLORTERM
      GTK_MODULES QT_QPA_PLATFORMTHEME
      DESKTOP_SESSION XDG_CURRENT_DESKTOP
      XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME
      NO_COLOR FORCE_COLOR
    )

    preserve_all=false
    extra_keep=()
    run0_args=()
    pos_args=()
    no_pty=false

    while [[ $# -gt 0 ]]; do
      case "$1" in
        -E | --preserve-env)
          preserve_all=true
          shift
          ;;
        --preserve-env=*)
          IFS=',' read -ra vars <<< "''${1#*=}"
          for v in "''${vars[@]}"; do extra_keep+=("$v"); done
          shift
          ;;
        -u | --user)
          run0_args+=("--user=$2")
          shift 2
          ;;
        -i | --login)
          run0_args+=(--via-shell "--chdir=~")
          shift
          ;;
        --via-shell)
          run0_args+=(--via-shell)
          shift
          ;;
        -C | --chdir)
          run0_args+=("--chdir=$2")
          shift 2
          ;;
        -p | --pty)
          run0_args+=(--pty)
          shift
          ;;
        --no-pty)
          no_pty=true
          shift
          ;;
        --)
          shift
          pos_args+=("$@")
          break
          ;;
        -*)
          run0_args+=("$1")
          shift
          ;;
        *)
          pos_args+=("$@")
          break
          ;;
      esac
    done

    if [[ ''${#pos_args[@]} -gt 0 ]]; then
      cmd="''${pos_args[0]}"
      if [[ "$cmd" != */* ]]; then
        resolved=$(PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin command -v -- "$cmd" 2>/dev/null || true)
        if [[ -z "$resolved" ]]; then
          echo "run0-sudo: comando não encontrado: $cmd" >&2
          exit 127
        fi
        pos_args[0]="$resolved"
      fi
      run0_args+=("''${pos_args[@]}")
    fi

    env_args=()
    if [[ "$preserve_all" == "true" ]]; then
      while IFS='=' read -r name value; do
        env_args+=("--setenv=$name=$value")
      done < <(env)
    else
      for var in "''${AUTO_KEEP[@]}" "''${extra_keep[@]+"''${extra_keep[@]}"}"; do
        if [[ -n "''${!var:-}" ]]; then
          env_args+=("--setenv=$var=''${!var}")
        fi
      done
    fi

    if [[ "$no_pty" != "true" ]] && [[ " ''${run0_args[*]} " != *" --pty "* ]]; then
      has_stdin=false
      [[ -t 0 ]] && has_stdin=true
      if [[ "$has_stdin" == "true" ]] || [[ ''${#pos_args[@]} -eq 0 ]]; then
        run0_args=(--pty "''${run0_args[@]+"''${run0_args[@]}"}")
      fi
    fi

    exec "$RUN0" "''${env_args[@]+"''${env_args[@]}"}" "''${run0_args[@]+"''${run0_args[@]}"}"
  '';
}
