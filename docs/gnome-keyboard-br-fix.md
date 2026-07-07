# Fixing the ABNT2 keyboard in GNOME (Wayland)

## Problem

In GNOME/Wayland sessions with an ABNT2 keyboard, two incorrect behaviors occurred:

1. **Dead key + space didn't produce the literal accent symbol** (e.g. `´`, `~`, `^`) — only the AltGr+accent combination worked.
2. **After relogin, the layout reverted to US**, even with the Brazilian layout configured.

## Root cause

GNOME starts IBus automatically via `org.freedesktop.IBus.session.GNOME.service`. IBus intercepts keyboard events and processes them with its own Compose table implementation (`IBusEngineSimple`), which is **completely independent** of libxkbcommon. This creates a conflict:

- The `br` XKB layout defines `dead_acute + space → ´` (U+00B4, SPACING ACUTE ACCENT) via the XKB state machine.
- IBus's Compose tables (libx11's pt_BR.UTF-8) define `<dead_acute> <space> → '` (apostrophe U+0027, the canonical X11 convention).

IBus responds `TRUE` (it consumed the event) before Mutter/libxkbcommon processes the combination, so IBus's Compose table always wins. The default `~/.XCompose` file doesn't fix this because IBus loads `~/.config/ibus/Compose` exclusively — only if no custom file exists does it fall through to the locale files.

## Solution

The fix uses three layers.

### 1. System XKB layout — `modules/system/core/localization.nix`

```nix
services.xserver.xkb = {
  layout  = "br";
  variant = "abnt2";
  model   = "abnt2";
};
```

Needed so `localectl` reports `X11 Layout: br` and IBus loads the correct engine (`xkb:br::por`).

> **Note:** `services.xserver.enable = false` is still valid — this block only configures XKB metadata, without starting the Xorg server.

### 2. GNOME input source defaults — `modules/system/desktop/desktop.nix`

```nix
programs.dconf.profiles.user.databases = [{
  settings = {
    "org/gnome/desktop/input-sources" = {
      sources     = [(lib.gvariant.mkTuple ["xkb" "br"])];
      mru-sources = [(lib.gvariant.mkTuple ["xkb" "br"])];
      xkb-model   = "abnt2";
    };
  };
}];
```

- `sources` and `mru-sources`: ensure GNOME uses the `br` layout. Without `mru-sources`, the field stays empty and GNOME may not remember the layout across sessions.
- `xkb-model`: without it, GNOME uses the generic `pc105+inet` instead of `abnt2`.

### 3. IBus Compose file — `home/modules/desktop/ibus-compose.nix`

IBus loads `~/.config/ibus/Compose` as the **first and exclusive** Compose table source when the file exists. When no custom file exists, IBus uses `en_US.UTF-8` as its internal fallback locale — ignoring the system locale. Forcing the load of `%L` (which expands to `pt_BR.UTF-8`) is enough to fix the behavior.

The definition was moved from the per-user module (`home/users/abutre/home.nix`) to a shared module applied to **all GNOME users** via `home/common.nix`:

```nix
# home/modules/desktop/ibus-compose.nix
{ lib, desktop ? "gnome", ... }:
let
  isGnome = desktop == "gnome";
in
{
  xdg.configFile = lib.mkIf isGnome {
    "ibus/Compose".text = ''
      include "%L"
    '';
  };
}
```

`include "%L"` expands to the system locale's table (`pt_BR.UTF-8/Compose`), loading all the ABNT2 dead key combinations, including `dead_key + space`. The `lib.mkIf isGnome` guard ensures the file is only created in GNOME sessions (a no-op for KDE Plasma and other desktops).

The module is imported in `home/common.nix`:

```nix
imports = [
  ./modules/apps/browsers/google-chrome.nix
  ./modules/desktop/ibus-compose.nix
];
```

It's also necessary to configure IBus to work correctly in pure Wayland:

```nix
dconf.settings."desktop/ibus/general" = {
  use-system-keyboard-layout = true;   # avoids calling setxkbmap (absent on Wayland)
  preload-engines = [ "xkb:br::por" ]; # correct engine at session startup
};
```

## Dead key + space behavior

With IBus loading the `pt_BR.UTF-8` table via `include "%L"`:

| Sequence | Result |
|---|---|
| `dead_acute` + letter | letter with an acute accent (`á`, `é`, ...) |
| `dead_acute` + `dead_acute` | literal symbol `´` |
| `dead_acute` + `space` | apostrophe `'` (as defined in the pt_BR table) |
| `dead_tilde` + `space` | `~` |
| `dead_circumflex` + `space` | `^` |
| `dead_diaeresis` + `space` | `¨` |

## Home Manager flow

Home Manager in this repository is a **NixOS module** — `nixos-rebuild switch` (or `just switch`) applies NixOS and HM together. After any change to Home Manager modules (e.g. `home/common.nix`), simply:

```bash
just switch
```

The `~/.config/ibus/Compose` file takes effect on the next IBus service restart (or relogin).

> **Note:** Since the `ibus-compose.nix` module is imported via `home/common.nix`, it's applied automatically to **all users** registered in the flake who use GNOME as their desktop. Nothing needs to be added to the per-user modules.

## What was ruled out

| Item | Reason |
|---|---|
| `ConditionPathExists=!/run/current-system` drop-in disabling IBus | A more aggressive earlier solution; replaced by the `ibus/Compose` file |
| `GTK_IM_MODULE=xim` + `input-method-env-override` service | `im-xim.so` doesn't exist in nixpkgs for Wayland |
| `~/.XCompose` with manual mappings | IBus doesn't read `~/.XCompose` when `~/.config/ibus/Compose` exists |
| Explicit `dead_key + space` overrides in the Compose file | `include "%L"` alone already loads the pt_BR table with the correct mappings |
| `include` of the pt_BR table via `GTK_IM_MODULE=xim` | The missing `im-xim.so` module blocks this path |
| `console.keyMap = "br-abnt2"` for GNOME | Only affects the TTY console |
