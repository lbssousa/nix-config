# Copilot Instructions

## Build, test, and lint commands

This repository does not have a unit-test suite. The smallest repo-native checks are the individual CI validation steps:

- **Full validation:** `nix flake check --show-trace .`
- **Format check (CI-equivalent):** `nix run nixpkgs#nixfmt-rfc-style -- --check $(find . -name '*.nix' -not -path './.git/*')`
- **Lint:** `nix run nixpkgs#statix -- check .`
- **Dead code check:** `nix run nixpkgs#deadnix -- --fail .`

Useful local wrappers from `just`:

- **Format all Nix files:** `just fmt`
- **Run the full flake check:** `just check`
- **Build one system target without activating it:** `sudo just system build <host> [gnome|plasma]`
- **Test one system target without making it default:** `sudo just system test <host> [gnome|plasma]`
- **Apply one Home Manager target:** `just home switch <user@host> [gnome|plasma]`

## High-level architecture

- The root `flake.nix` is intentionally thin. Real composition lives under `dendritic/`, and `dendritic/imports.nix` auto-imports every `.nix` file in that tree except itself.
- `dendritic/data/hosts.nix` is the host inventory. `dendritic/flake/nixos-configurations.nix` turns each host into:
  - a canonical `nixosConfigurations.<host>` output using that host's `defaultDesktop`
  - explicit desktop variants `nixosConfigurations.<host>-gnome` and `nixosConfigurations.<host>-plasma`
- `dendritic/data/users.nix` is the user inventory. `dendritic/features/nixos-modules.nix` maps each listed username directly to `private/users/<name>.nix`, so user modules are inventory-driven rather than imported manually in each host.
- Home Manager is standalone. `dendritic/flake/home-configurations.nix` generates `homeConfigurations` for every user/host combination, always importing `home/common.nix` and optionally adding `private/home/users/<user>/home.nix` for per-user overrides.
- Unsuffixed Home Manager outputs are not tied to the host default desktop: `user@host` currently builds with the `gnome` desktop value, while `user@host-gnome` and `user@host-plasma` are also generated explicitly.
- Shared NixOS behavior belongs in `modules/system/**` and is assembled centrally via `dendritic/features/nixos-modules.nix`. `hosts/<host>/configuration.nix` should stay focused on host-specific hardware or overrides.
- The system is impermanent: `/` is tmpfs and durable state lives under `/persist`. If a change needs to survive reboot, check `modules/system/core/impermanence.nix` and `modules/system/users/users.nix` instead of assuming normal filesystem persistence.
- Secrets are wired through `sops-nix`. Wi-Fi profiles are generated in `modules/system/network/wifi.nix` from `secrets/*.yaml`, and the age key is expected at `/persist/etc/sops/age/keys.txt`.
- Secure Boot is host-specific. `barbudus` enables `boot.lanzaboote` with `pkiBundle = "/persist/etc/secureboot"`, and the host config also recreates `/var/lib/sbctl` as a symlink to that persistent location on boot.
- The install/post-install flow is split: `scripts/install.sh` creates the PKI bundle before `nixos-install` for lanzaboote hosts, while `scripts/setup-secureboot.sh` is the post-boot script that signs remaining EFI binaries, verifies them, and enrolls the keys into firmware.

## Key conventions

- Keep documentation, comments, and help text in Portuguese when editing repo-owned text unless the file is already clearly English-first.
- Add or remove hosts and users through the dendritic inventories first:
  - hosts in `dendritic/data/hosts.nix`
  - users in `dendritic/data/users.nix`
- Define NixOS users with the helper pattern used in `private/users/*.nix`:
  `import ./mkUser.nix { inherit pkgs lib; } { ... }`
- Keep Home Manager customizations separate from system users. System accounts live in `private/users/`; per-user HM overrides live in `private/home/users/<user>/home.nix`.
- Do not assume `nixos-rebuild` updates Home Manager. System changes and HM changes are applied independently.
- Flake evaluation only sees files tracked by Git. This is especially important for new `private/users/*` files and host files during installation or first-time setup.
- `barbudus` is the Secure Boot host. Its setup relies on lanzaboote plus a persistent PKI bundle at `/persist/etc/secureboot`.
- Keep secrets out of plain Nix values. Follow the pattern in `modules/system/network/wifi.nix`: declare a `sops.secrets.*` entry, then inject `config.sops.placeholder.<name>` into generated config files.
- Do not change Secure Boot paths casually. The repo assumes `/persist/etc/secureboot` in the host config, install script, and post-install verification flow.
