# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Commands

All commands run from the repo root (typically `/etc/nixos` on deployed systems, or the development checkout). Use `run0` instead of `sudo` for privilege escalation.

```bash
# Apply NixOS system + Home Manager (Home Manager is a NixOS module — both deploy together)
just switch                        # current host
just switch barbudus               # specific host

# NixOS subcommands
just nixos switch [host]           # apply system config (includes Home Manager)
just nixos test [host]             # activate without adding to boot menu (ephemeral)
just nixos boot [host]             # stage for next boot only
just nixos diff [host]             # preview changes vs current system (uses nvd)
just build [host]                  # build without activating

# Update flake inputs
just update                        # update all inputs, auto-commits flake.lock
just auto_commit=false update      # update without committing
just upgrade [host]                # update inputs + switch

# Validation (run before committing)
just fmt          # format all .nix files with nixfmt
just lint         # statix static analysis
just deadcode     # deadnix dead-code check
just check        # full nix flake check (slow)
just validate     # fmt-check + lint + deadcode + check

# Info
just systems      # list all nixosConfigurations in the flake

# Garbage collection
just gc           # delete generations older than 30d
just gc full      # delete all old generations
```

The pre-commit hook automatically runs `nixfmt --check`, `statix`, and `deadnix` on staged `.nix` files. Activate it once with `just hooks`.

`just update` auto-commits and pushes `flake.lock` when the file changes. Suppress with `just auto_commit=false update`.

### Shell aliases (bash/zsh/fish — defined in `home/common.nix`)

These are available in every user's interactive shell. All NixOS aliases use `run0` for privilege escalation (polkit/YubiKey, no password prompt) and pass `SSH_AUTH_SOCK` so `nixos-rebuild` can fetch SSH-gated flake inputs (e.g. `nix-secrets`). Because Home Manager is a NixOS module, every `nixos-rebuild` also deploys all HM changes.

| Alias | Expands to | Effect |
|-------|-----------|--------|
| `nrs` | `run0 … nixos-rebuild switch --flake $(_nix_cfg)` | Rebuild + activate NixOS **and** HM immediately |
| `nrb` | `run0 … nixos-rebuild boot --flake $(_nix_cfg)` | Stage next boot only — current session unchanged |
| `nru` | `run0 … nix flake update … && nixos-rebuild switch …` | Update all flake inputs, then rebuild + activate |
| `hmn` | `home-manager news` | Show HM changelog since last generation |

`_nix_cfg()` resolves the flake path: `/etc/nixos` when populated (deployed system), otherwise `$(xdg-user-dir PROJECTS)/lbssousa/nix-config` (development checkout).

The `just` function is also shadowed in the shell to always point to `$(_nix_cfg)/justfile`, so `just switch` works from any directory without specifying `--justfile`.

## Architecture

### Flake Composition (dendritic pattern)

`flake.nix` is intentionally thin — it delegates to `flake-parts` and the `dendritic/` layer. `dendritic/imports.nix` auto-imports every `.nix` file under `dendritic/` (except itself), so adding a new file there is enough to wire it in.

The two central inventories drive all flake outputs:

- **`dendritic/data/hosts.nix`** — host registry. Each entry produces `nixosConfigurations.<host>` and `diskoConfigurations.<host>`.
- **`dendritic/data/users.nix`** — user list. Each username maps to `users/<name>.nix` (NixOS account) and, if it exists, `home/users/<name>/home.nix` (HM override).

### How NixOS configurations are assembled

`dendritic/flake/nixos-configurations.nix` builds each host by stacking:
1. Shared flake inputs modules (disko, preservation, sops-nix)
2. All modules in `dendritic/nixos.sharedModules` (defined in `dendritic/features/nixos-modules.nix`)
3. All user account modules from `users/<name>.nix`
4. Host-specific: `hosts/<host>/hardware-configuration.nix` + `hosts/<host>/configuration.nix`
5. `hostSpec.extraNixosModules` (per-host extra modules; currently empty for both hosts)

`hosts/<host>/configuration.nix` should only contain host-specific overrides — shared behavior belongs in `modules/system/`.

### flake-parts modules in `dendritic/flake/`

Beyond configuration assembly, several files in `dendritic/flake/` are flake-parts modules that contribute to shared NixOS config or export flake packages:

- **`gnome-wrapper.nix`** — adds a GNOME NixOS module to `dendritic.nixos.sharedModules` (GDM, GNOME desktop, Flatpak declarations, dconf defaults, QT/XKB env vars) and exports `packages.gnome-extensions` (PaperWM + Appindicator + Caffeine).
- **`helix-wrapper.nix`** — builds and exports `packages.helix`: Helix editor wrapped with GABC/Gregorio tree-sitter grammar, texlab + ltex-ls + gregorio-lsp in PATH, and the full editor/LSP/keybindings config baked in via `nix-wrapper-modules`.
- **`pkgs.nix`** — wires the local overlay into `_module.args.pkgs` for all `perSystem` modules.

### Home Manager as NixOS module

`dendritic/flake/home-nixos-module.nix` adds `home-manager.nixosModules.home-manager` to `dendritic.nixos.sharedModules` and wires every user's HM config via `home-manager.users.<name>`. Each user's config always imports `home/common.nix` (shell config, git, neovim, starship, fzf, zoxide) and adds `home/users/<name>/home.nix` when present. HM and NixOS deploy together via `just switch` — no separate `home-manager switch` step.

Key HM module settings:
- `useGlobalPkgs = true` — HM uses the NixOS system pkgs (overlay + allowUnfree inherited)
- `useUserPackages = true` — packages install to `/etc/profiles/per-user/<user>` (in PATH automatically)
- `backupFileExtension = "bkp"` — conflicting files are backed up rather than failing

### Local packages and overlay

`overlays/default.nix` defines a nixpkgs overlay with packages that are not (yet) in upstream nixpkgs:

- **Gregorio/GABC** tools: `gregorio-lsp`, `grefmt`, `grelint`, `tree-sitter-gregorio`, `tree-sitter-gregorio-nvim`, `gregorio-nvim`
- **Fingerprint** (Goodix sensor 27c6:538d on barbudus): `libfprint-goodix`, `fprintd-goodix`, `goodix-fp-dump`
- **Brave Origin**: `brave-origin-beta`, `brave-origin-nightly` (simplified Brave without rewards/wallet/AI)

`dendritic/features/local-overlay.nix` wires this overlay into all `nixosConfigurations`. HM inherits it automatically via `home-manager.useGlobalPkgs = true`. New packages go in `pkgs/<name>/package.nix` and are registered in `overlays/default.nix`.

### Preservation

`/` is a **tmpfs** — wiped clean at every boot. Durable state lives under `/persist` (a Btrfs subvolume). If a change needs to survive reboot, check `modules/system/core/preservation.nix` before assuming normal filesystem persistence. `/home`, `/nix`, `/var/log`, `/var/lib/containers`, and `/var/lib/flatpak` are separate persistent Btrfs subvolumes.

### Secrets

Managed via `sops-nix`. The age key lives at `/persist/etc/sops/age/keys.txt`. The `nix-secrets` flake input (`git+ssh://git@github.com/lbssousa/nix-secrets`) is a private SSH-accessed repo that supplies user full names (referenced as `inputs.nix-secrets.${username}.fullName` in `modules/system/users/descriptions.nix`) and any other sensitive values. Follow the pattern in `modules/system/network/wifi.nix`: declare `sops.secrets.*` entries and inject `config.sops.placeholder.<name>` into generated files — never put secrets in plain Nix values.

## Key Conventions

- **Language**: Keep comments, docs, and help text in **Portuguese** unless the file is already clearly English-first.
- **Privilege escalation**: Use `run0` (not `sudo`) for all privileged commands — this system uses systemd's `run0`.
- **Git tracking**: Nix flakes only see files tracked by git. Always `git add` new files (e.g., `users/<name>.nix`, `home/users/<name>/home.nix`) before evaluating or installing.
- **Adding a user**: (1) copy `users/skeleton.nix` → `users/<name>.nix`, (2) add to `dendritic/data/users.nix`, (3) `git add` both files, (4) rebuild. The initial password is `"nixos"` and users are forced to change it on first login. User descriptions (full names) come from `nix-secrets`, not from the user files.
- **Adding a host**: (1) create `hosts/<host>/{configuration,hardware-configuration,disko}.nix`, (2) register in `dendritic/data/hosts.nix`, (3) `git add` all new files.
- **User accounts use `mkUser.nix`**: `import ./mkUser.nix { inherit pkgs lib; } { username = "..."; uid = NNN; hasSudo = false; }` — always set a fixed `uid` to avoid ownership issues.
- **Secure Boot**: `barbudus` only, via `boot.loader.limine.secureBoot` (no shim/MOK — Limine signs its own EFI binary with sbctl and verifies kernel/initrd via a BLAKE2B checksum embedded in the signed, enrolled `limine.conf`). Keys live at `/persist/etc/secureboot`, symlinked to `/var/lib/sbctl` (the fixed path sbctl expects — the Limine module has no `pkiBundle`-style option). Do not change this path — it's assumed in the host config, install script, and post-install flow.
- **Shadow persistence**: `/etc/shadow` is NOT managed by preservation directly. `modules/system/users/users.nix` uses an activation script (`restoreShadow`) plus a `persistShadow` systemd path unit to keep passwords durable across reboots despite the tmpfs root.

## Hosts

| Host | Hardware | Notes |
|------|----------|-------|
| `barbudus` | Dell Inspiron 14 5490 — Intel i5-10210U, NVIDIA GeForce MX230 | Secure Boot (Limine), NVIDIA PRIME offload, Goodix fingerprint sensor |
| `bigodon` | Morefine M6 Mini-PC — Intel N200, Intel UHD Graphics | No discrete GPU, no Secure Boot |
