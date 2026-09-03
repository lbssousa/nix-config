# Copilot Instructions

## Build, test, and lint commands

This repository does not have a unit-test suite. The smallest repo-native checks are the individual CI validation steps:

- **Full validation:** `nix flake check --show-trace .`
- **Format check (CI-equivalent):** `nix run nixpkgs#nixfmt -- --check $(find . -name '*.nix' -not -path './.git/*')`
- **Lint:** `nix run nixpkgs#statix -- check .`
- **Dead code check:** `nix run nixpkgs#deadnix -- --fail .`

Useful local wrappers from `just`:

- **Format all Nix files:** `just fmt`
- **Run the full flake check:** `just check`
- **Build one host without activating it:** `just build <host>`
- **Preview changes vs. the running system:** `just nixos diff <host>`
- **Apply one Home Manager target standalone:** `just home switch <user@host>`

## High-level architecture

- The root `flake.nix` is intentionally thin. Real composition lives under `dendritic/`, and `dendritic/imports.nix` auto-imports every `.nix` file in that tree except itself.
- `dendritic/data/hosts.nix` is the host inventory — just `system` and `extraNixosModules` per host, no desktop-variant selection. `dendritic/flake/nixos-configurations.nix` turns each entry into a single `nixosConfigurations.<host>` output.
- `dendritic/data/users.nix` is the user inventory. `dendritic/features/nixos-modules.nix` maps each listed username directly to `users/<name>.nix` (no `private/` prefix), so user modules are inventory-driven rather than imported manually in each host.
- Home Manager is wired two ways from one shared definition (`home/mkUserHome.nix`): as a NixOS module for every user (`dendritic/flake/home-nixos-module.nix`, applied together with `nixos-rebuild switch` — no separate HM step needed for this path), and standalone (`dendritic/flake/home-configurations.nix`, generating `homeConfigurations."<user>@<host>"` for every user/host pair, deployable independently via `home-manager switch` / `just home switch`).
- Shared NixOS behavior belongs in `modules/system/**` and is assembled centrally via `dendritic/features/nixos-modules.nix`. `hosts/<host>/configuration.nix` should stay focused on host-specific hardware or overrides.
- The desktop is the Noctalia v5 suite — Umbriel (compositor), Noctalia Shell, and Noctalia Greeter (replaces GDM, via greetd) — wired system-wide in `dendritic/flake/noctalia-wrapper.nix`. There's no per-host or per-user desktop selection.
- The system is impermanent: `/` is tmpfs and durable state lives under `/persist`; `/home`, `/nix`, `/var/log`, `/var/lib/containers` and `/var/lib/flatpak` are separate persistent Btrfs subvolumes (see `disko.nix`). If a change needs to survive reboot outside those subvolumes, check `modules/system/core/preservation.nix` instead of assuming normal filesystem persistence.
- Secrets are wired through `sops-nix`. Wi-Fi profiles are generated in `modules/system/network/wifi.nix`, and the system age key is expected at `/persist/etc/sops/age/keys.txt`.
- FIDO2/U2F PAM/PolKit authentication (pam_u2f) is opt-in via `security.fido2Auth.enable` (`modules/system/security/yubikey.nix`), off by default on every host — fingerprint auth, PC/SC and the keyring stay on regardless of that flag.
- Homebrew (Linuxbrew) is available system-wide, similar to Flatpak — shared prefix set up in `modules/system/tools/homebrew.nix`, bootstrap + declarative Brewfile in `modules/home/apps/homebrew.nix`.
- Secure Boot is host-specific. `barbudus` enables `boot.loader.limine.secureBoot` (Limine signs its own EFI binary via sbctl — no shim/MOK), and the host config recreates `/var/lib/sbctl` as a symlink to `/persist/etc/secureboot` on boot (the Limine module has no `pkiBundle`-style option — sbctl always expects keys at that fixed path).
- The install/post-install flow is split: `scripts/install.sh` creates the PKI bundle before `nixos-install` for Secure Boot hosts, while `scripts/setup-secureboot.sh` is the post-boot script that signs remaining EFI binaries, verifies them, and enrolls the keys into firmware.

## Key conventions

- Keep documentation, comments, and help text in English. Exception: functional data tied to the system's `pt_BR` locale (e.g. the `eza` theme filenames in `home/common.nix`, which must match the real on-disk folder names like `Documentos`/`Imagens`) stays in Portuguese.
- Add or remove hosts and users through the dendritic inventories first:
  - hosts in `dendritic/data/hosts.nix`
  - users in `dendritic/data/users.nix`
- Define NixOS users with the helper pattern used in `users/*.nix`:
  `import ./mkUser.nix { inherit pkgs lib; } { username = "..."; uid = NNN; hasSudo = false; }`
- Keep Home Manager customizations separate from system users. System accounts live in `users/`; per-user HM overrides live in `home/users/<user>/home.nix`.
- Home Manager is a NixOS module — a `nixos-rebuild switch` (`just switch`) applies both NixOS and every managed user's HM config together. Only the standalone `homeConfigurations` path needs a separate `home-manager switch` (`just home switch`), and that path alone doesn't apply system-level changes.
- Flake evaluation only sees files tracked by Git. This is especially important for new `users/*.nix` or `home/users/<user>/home.nix` files — `git add` them before evaluating.
- `barbudus` is the Secure Boot host. Its setup relies on `boot.loader.limine.secureBoot` plus a persistent PKI bundle at `/persist/etc/secureboot`.
- Keep secrets out of plain Nix values. Follow the pattern in `modules/system/network/wifi.nix`: declare a `sops.secrets.*` entry, then inject `config.sops.placeholder.<name>` into generated config files.
- Do not change Secure Boot paths casually. The repo assumes `/persist/etc/secureboot` in the host config, install script, and post-install verification flow.
- Use `run0` instead of `sudo` for all privileged commands (e.g. `run0 nixos-rebuild switch`, `run0 nix build`, `run0 just switch`). This machine uses systemd's `run0` as the privilege escalation tool.
