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
# Via Just (auto-detects the current host):
just switch

# A specific host:
just switch barbudus

# Or directly via nixos-rebuild:
sudo nixos-rebuild switch --flake /etc/nixos
```

### Add a customization for a new user

1. Create `home/users/<user>/home.nix` (use `home/users/abutre/home.nix` as an example).
2. Add the file to the git index:
   ```bash
   git add home/users/<user>/home.nix
   ```
3. [`home/mkUserHome.nix`](mkUserHome.nix)'s `userModule` function detects the
   file via `lib.pathExists` and imports it automatically — used by both the
   NixOS-module path ([`dendritic/flake/home-nixos-module.nix`](../dendritic/flake/home-nixos-module.nix))
   and the standalone `homeConfigurations` path
   ([`dendritic/flake/home-configurations.nix`](../dendritic/flake/home-configurations.nix)).

Users with no customization only inherit `home/common.nix`.
