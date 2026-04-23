# modules

Módulos Nix reutilizáveis organizados em duas categorias:

- **[system/](system/)** — Módulos system-wide, utilizados pelo `nixos-rebuild` (NixOS modules).
- **[user/](user/)** — Módulos user-wide, utilizados pelo `home-manager` (Home Manager modules).

## Como usar

### Módulos de sistema

Importe no arquivo de configuração do host (`hosts/<host>/configuration.nix`):

```nix
imports = [
  ../../modules/system/core/common.nix
  ../../modules/system/desktop/desktop.nix
  # ... outros módulos
];
```

### Módulos de usuário

Importe no arquivo do usuário (`users/<usuario>.nix`) ou diretamente na configuração do home-manager:

```nix
home-manager.users.meuusuario = { imports = [ ../../modules/user/apps/brave.nix ]; ... };
```

## Estrutura

```
modules/
├── system/          # NixOS modules (system-wide)
│   ├── audio/       # PipeWire / áudio
│   ├── boot/        # Boot loader, Plymouth
│   ├── containers/  # Podman rootless, Distrobox
│   ├── core/        # Configurações base + impermanência + usuários
│   ├── desktop/     # GNOME + Flatpak
│   ├── hardware/    # Impressão e hardware específico
│   ├── network/     # SSH e rede
│   ├── security/    # TPM2, Secure Boot
│   ├── shell/       # Shells (Bash, Fish, Zsh)
│   ├── tools/       # Pacotes do sistema, Homebrew, lbnix
│   └── users/       # Definição de usuários, sudo
└── user/            # Home Manager modules (user-wide)
    ├── apps/        # Aplicativos do usuário (Brave, etc.)
    ├── dev/         # Ferramentas de desenvolvimento
    └── shell/       # Configuração de shell do usuário
```
