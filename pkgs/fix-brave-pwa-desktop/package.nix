{
  writeShellApplication,
  gnugrep,
  gnused,
  coreutils,
  desktop-file-utils,
}:

writeShellApplication {
  name = "fix-brave-pwa-desktop";

  runtimeInputs = [
    gnugrep
    gnused
    coreutils
    desktop-file-utils
  ];

  text = ''
    # Fixes .desktop files for PWAs installed by Brave (Flatpak).
    #
    # Bugs fixed:
    #   1. Shell-style single quotes in Exec= arguments
    #      (e.g., flatpak 'run' '--command=brave') — violates the
    #      freedesktop.org spec. Fix: strips the single quotes.
    #
    #   2. Unescaped '?' in shortcut URLs inside Exec=
    #      (e.g., https://www.youtube.com/results?feature=app_shortcuts) —
    #      '?' is reserved outside quotes per the freedesktop.org spec.
    #      Fix: escapes it as '\?'.
    #
    #   3. Missing StartupNotify.
    #      Fix: inserts 'StartupNotify=true' after the StartupWMClass= line.
    #
    #   4. StartupWMClass in the wrong format (crx_<id> instead of
    #      brave-<id>-<profile>). On Wayland, GNOME Shell uses
    #      xdg_toplevel.app_id (not X11's WM_CLASS) to match windows to
    #      .desktop files. Brave Flatpak sets app_id to the part of the
    #      filename after "com.brave.Browser.flextop." (e.g.,
    #      "brave-hnp...-Default"), but the .desktop files Brave generates
    #      use the legacy X11 "crx_" prefix, so GNOME falls back to
    #      matching by cgroup (app-flatpak-com.brave.Browser-*) and shows
    #      the generic Brave icon instead.
    #      Fix: replaces StartupWMClass with the ID derived from the
    #      filename.

    APPS_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/applications"
    BACKUP_DIR="$APPS_DIR/.brave-pwa-backups"
    FIXED=0
    SKIPPED=0
    ERRORS=0

    needs_fix() {
        local file="$1"
        local flextop_id
        flextop_id=$(basename "$file" .desktop | sed 's/^com\.brave\.Browser\.flextop\.//')
        grep -q "^Exec=.*'" "$file" 2>/dev/null \
            || grep -q "^Exec=.*[^\\\\]?" "$file" 2>/dev/null \
            || ! grep -q "^StartupNotify=" "$file" 2>/dev/null \
            || ! grep -q "^StartupWMClass=''${flextop_id}$" "$file" 2>/dev/null
    }

    fix_file() {
        local file="$1"
        local name
        name=$(basename "$file")

        if ! needs_fix "$file"; then
            echo "  OK (no fix needed): $name"
            ((SKIPPED++)) || true
            return 0
        fi

        mkdir -p "$BACKUP_DIR"
        local backup
        backup="$BACKUP_DIR/$name.$(date +%Y%m%d-%H%M%S).bak"
        cp "$file" "$backup"

        local ok=true
        local flextop_id
        flextop_id=$(basename "$file" .desktop | sed 's/^com\.brave\.Browser\.flextop\.//')

        # Fix 1: strip shell-style single quotes from all Exec= lines
        sed -i "/^Exec=/s/'//g" "$file" || ok=false

        # Fix 2: escape unescaped '?' in Exec= lines (e.g., URLs with a
        # query string). Turns '?' into '\?' only when not already
        # preceded by '\'.
        sed -i '/^Exec=/s/\([^\]\)?\([^?]\)/\1\\?\2/g' "$file" || ok=false

        # Fix 3: insert StartupNotify=true after StartupWMClass= if missing
        if ! grep -q "^StartupNotify=" "$file"; then
            sed -i '/^StartupWMClass=/a StartupNotify=true' "$file" || ok=false
        fi

        # Fix 4: correct StartupWMClass to the format used by Brave
        # Flatpak on Wayland. The xdg_toplevel.app_id Brave sends is the
        # flextop ID without the Flatpak prefix, e.g.
        # "com.brave.Browser.flextop.brave-hnp...-Default" becomes
        # "brave-hnp...-Default".
        if ! grep -q "^StartupWMClass=''${flextop_id}$" "$file"; then
            sed -i "s/^StartupWMClass=.*/StartupWMClass=''${flextop_id}/" "$file" || ok=false
        fi

        if $ok; then
            echo "  Fixed: $name  (backup: $(basename "$backup"))"
            ((FIXED++)) || true
        else
            echo "  ERROR fixing: $name" >&2
            cp "$backup" "$file"
            ((ERRORS++)) || true
        fi
    }

    echo "Checking Brave Flatpak PWA .desktop files in:"
    echo "  $APPS_DIR"
    echo

    shopt -s nullglob
    files=("$APPS_DIR"/com.brave.Browser.flextop.brave-*.desktop)

    if [[ ''${#files[@]} -eq 0 ]]; then
        echo "No Brave PWA .desktop files found."
        exit 0
    fi

    for f in "''${files[@]}"; do
        fix_file "$f"
    done

    echo
    echo "Result: $FIXED fixed | $SKIPPED already OK | $ERRORS error(s)"

    if [[ $FIXED -gt 0 ]]; then
        echo
        echo "Updating application database..."
        update-desktop-database "$APPS_DIR" 2>/dev/null && echo "Done." || echo "Warning: update-desktop-database failed (non-critical)."
    fi

    if [[ $ERRORS -gt 0 ]]; then
        exit 1
    fi
  '';
}
