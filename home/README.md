# home

Home Manager configurations — integrated into NixOS as a system module.
HM is applied automatically together with `nixos-rebuild switch`.

## Structure

| File/Folder | Description |
|---------------|-----------|
| [`common.nix`](common.nix) | Base HM configuration applied to **all** users |
| [`modules/`](../modules/home/) | Reusable HM modules (importable by users) |
| [`users/`](users/) | Per-user customizations |

## Usage

### Apply the system configuration (includes Home Manager)

```bash
# Via Just (auto-detects the active host and desktop):
just switch

# Explicitly specifying the desktop:
just switch plasma

# Or directly via nixos-rebuild:
sudo nixos-rebuild switch --flake /etc/nixos
```

### Add a customization for a new user

1. Create `home/users/<user>/home.nix` (use `home/users/abutre/home.nix` as an example).
2. Add the file to the git index:
   ```bash
   git add home/users/<user>/home.nix
   ```
3. The [`modules/system/users/home-manager.nix`](../modules/system/users/home-manager.nix) module
   detects the file via `lib.pathExists` and imports it automatically.

Users with no customization only inherit `home/common.nix`.
