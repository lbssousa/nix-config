# Especificações do Projeto NixOS Config

Este documento registra os requisitos e especificações para a configuração do NixOS deste repositório.
Serve como referência para manutenção e extensão futura.

## Propósito Geral

Propiciar uma experiência de uso similar à do Fedora Silverblue ou do projeto Bluefin, com:
- Sistema base enxuto e declarativo via Nix Flakes
- Uso massivo de Flatpaks para aplicações GUI
- Aplicativos CLI instalados via Homebrew (Linuxbrew)
- Sistema efêmero (impermanence) com raiz limpa a cada boot
- Dados importantes preservados em subvolumes Btrfs dedicados

## Particionamento de Disco

### Requisitos

- Suporte a UEFI
- Criptografia completa do disco via LUKS + LVM
- Particionamento declarativo via nix-community/disko
- Sistema de arquivos Btrfs para a partição principal
- Swap híbrida: zram (performance) + swap em disco (hibernação)
- Sistema efêmero via nix-community/impermanence

### Esquema de Partições

```
Disco (ex: /dev/nvme0n1)
├── Partição 1: ESP (512 MB, FAT32)
│   └── Mountpoint: /boot
└── Partição 2: LUKS (restante do disco)
    └── LVM VG: root_vg
        ├── LV swap: 20 GB
        │   └── Swap (para hibernação)
        └── LV root: 100%FREE
            └── Btrfs
```

### Subvolumes Btrfs

A convenção `@` é compatível com ferramentas como Timeshift e amplamente adotada pela comunidade.

| Subvolume | Mountpoint | Características |
|-----------|-----------|-----------------|
| `@` | `/` | Efêmero — limpo a cada boot (rollback para @blank) |
| `@home` | `/home` | Preservado — diretórios de usuário |
| `@nix` | `/nix` | Preservado — Nix store (essencial) |
| `@persist` | `/persist` | Preservado — dados persistentes do sistema (impermanence) |
| `@log` | `/var/log` | Preservado — logs do sistema (compressão off) |
| `@containers` | `/var/lib/containers` | Preservado — dados de containers |
| `@flatpak` | `/var/lib/flatpak` | Preservado — aplicações Flatpak |
| `@snapshots` | `/.snapshots` | Preservado — snapshots Btrfs para backup |

**Opções de montagem globais:**
- `compress=zstd` (exceto `@log`: sem compressão)
- `noatime` (equivalente a relatime desabilitado)

**Impermanence — estratégia de rollback:**
1. No boot, o initrd monta o volume Btrfs bruto em `/btrfs_tmp`
2. Deleta o subvolume `@` atual
3. Cria um novo `@` como cópia do snapshot somente-leitura `@blank`
4. Desmonta `/btrfs_tmp` e o boot continua normalmente

### Swap Híbrida

**Por host (16 GB RAM):**
| Componente | Tamanho | Prioridade | Objetivo |
|-----------|---------|------------|----------|
| zram (zstd) | 8 GB (50% RAM) | 100 (primária) | Performance diária |
| Swap em disco | 20 GB | 5 (backup) | Hibernação |

**Comportamento:**
1. Sistema usa zram primeiro (mais rápido, não desgasta SSD)
2. Quando zram esgota, usa swap em disco
3. Hibernação usa swap em disco

## Hosts

### barbudus (Dell Inspiron 14 5490)

- **CPU**: Intel i5-10210U
- **RAM**: 16 GB DDR4
- **GPU**: Intel UHD 620 (integrada) + NVIDIA GeForce MX230 (discreta)
- **Storage**: NVMe SSD
- **Características especiais**:
  - Drivers NVIDIA proprietários (580.x) com PRIME offload
  - Secure Boot via lanzaboote (assina módulos NVIDIA)
  - Sensor de impressão digital Goodix (libfprint fork do infinytum)
  - Scripts goodix-fp-dump para diagnóstico
  - Gestão de energia: power-profiles-daemon + thermald

### bigodon (Morefine M6)

- **CPU**: Intel N200
- **RAM**: 16 GB DDR4
- **GPU**: Intel UHD Graphics (integrada, Jasper Lake)
- **Storage**: NVMe SSD
- **Características especiais**:
  - Driver Intel Xe para GPU moderna
  - VA-API com intel-media-driver (iHD)

## Configuração de Ambiente

### Shell

- Shells disponíveis: Bash, Fish, Zsh
- Shell padrão para novos usuários: **Zsh**
- Prompt: Starship (cross-shell)

### Editores

- Editores disponíveis: Neovim, Helix
- Editor padrão do sistema: **Neovim** (`$EDITOR=nvim`)

### Boot

- Gerenciador de boot: **systemd-boot** (padrão) / **lanzaboote** (barbudus, Secure Boot)
- Splash screen: Plymouth
- Configuração flicker-free: `quiet splash` + KMS no initrd
- Limite de configurações no boot menu: 10

### Impressão

- Driver Epson ESC-P/R versão 1 (`epson-escpr`) - compatível com L4160
- Driver Epson ESC-P/R versão 2 (`epson-escpr2`) - modelos mais novos
- Serviço `ecbd` habilitado por padrão
- Avahi para descoberta de impressoras na rede

## Ambiente Gráfico

### GNOME

- Sessão Wayland por padrão (via GDM)
- Aplicações GNOME instaladas via Flatpak (Flathub)
- Pacotes GNOME excluídos da instalação padrão:
  - gnome-software → substituído pelo **Bazaar** (Flatpak)
  - epiphany → substituído pelo **Brave** (Nix)
  - evince → substituído pelo **Papers** (Flatpak)
  - gnome-terminal → substituído pelo **Ptyxis** (Flatpak)

### Flatpak

- Instalações system-wide sem senha para usuários do grupo `wheel`
- Configurado via regra polkit (compatível com Silverblue)
- Repositório recomendado: Flathub

**Flatpaks recomendados para instalar:**
```bash
flatpak install flathub org.gnome.Papers          # PDF viewer
flatpak install flathub app.devsuite.Ptyxis       # Terminal
flatpak install flathub io.github.bazaar_cabinet.Bazaar  # App store
```

### Navegador

- **Brave** instalado via Nix (system-wide)
- Definido como browser padrão via xdg-mime
- Disponível para todos os usuários do sistema

### Fontes

- Noto Fonts (sans, serif, CJK, emoji)
- Liberation TTF
- JetBrains Mono Nerd Font (monospace padrão)
- FiraCode Nerd Font

## Containers

### Podman (rootless)

- Modo rootless habilitado (sem root para operações básicas)
- Alias `docker` disponível para compatibilidade
- DNS habilitado entre containers em compose
- Autolimpeza semanal de imagens não utilizadas

### Distrobox

- Permite executar qualquer distribuição Linux em containers
- Integração com o ambiente do usuário (home directory compartilhado)
- Compatível com Podman rootless

## Home Manager

- Integrado como módulo NixOS
- Usa pacotes globais do sistema (`useGlobalPkgs = true`)
- Configuração base em `home.nix`
- Configurações de usuário em `users/<usuario>.nix` (gitignored)

## Homebrew (Linuxbrew)

- Instalado em `/home/linuxbrew/.linuxbrew` para uso system-wide
- PATH configurado automaticamente para todos os usuários
- Diretório `/home/linuxbrew` preservado em `/persist`
- Instalação manual necessária após o setup do NixOS:
  ```bash
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  ```

## Impermanence (Sistema Efêmero)

### Como Funciona

1. O subvolume Btrfs `@` contém a raiz do sistema
2. No boot, antes de montar `/`, o initrd monta o volume Btrfs bruto
3. Deleta o subvolume `@` e cria um novo a partir do snapshot `@blank`
4. Isso garante que a raiz está sempre "limpa" (como na instalação inicial)
5. Arquivos e diretórios importantes são preservados via bind mounts de `/persist`

### Dados Preservados Automaticamente (Sistema)

- `/etc/nixos` - Configuração do NixOS
- `/etc/NetworkManager/system-connections` - Conexões de rede
- `/var/lib/systemd` - Estado do systemd
- `/var/lib/nixos` - Estado interno do NixOS
- `/var/lib/bluetooth` - Dispositivos Bluetooth
- `/var/db/sudo` - Timestamps do sudo
- `/etc/machine-id` - ID único da máquina
- Chaves SSH do servidor (configuradas em ssh.nix)

### Dados Preservados por Usuário (template)

- `~/Downloads`
- `~/Documents`
- `~/Pictures`, `~/Videos`, `~/Music`
- `~/.ssh`
- `~/.gnupg`
- `~/.local/share/keyrings`
- `~/.config/gh`
- `~/.local/share/flatpak`
- `~/.var/app`
- `~/.local/share/containers`
- Histórico do Bash e Zsh

## Segurança

### LUKS

- Criptografia AES-256 por padrão
- `allowDiscards = true` para melhor performance em SSDs
- Senha solicitada no boot via Plymouth como fallback

### TPM2 (Desbloqueio Automático LUKS)

- Módulo: `modules/tpm2.nix`
- Habilitado por padrão em todos os hosts
- Usa `systemd-cryptenroll` para vincular a chave LUKS ao TPM2
- PCRs verificados: 0 (firmware UEFI) + 2 (código de opção UEFI) + 7 (Secure Boot state)
- Fallback automático para senha manual se os PCRs mudarem
- Ferramentas incluídas: `tpm2-tools`, `tpm2-tss`
- Módulos do kernel carregados no initrd: `tpm_tis`, `tpm_crb`
- **Requer enrollment manual após instalação** (ver INSTALLATION.md)

### Secure Boot (barbudus)

- Implementado via lanzaboote
- Chaves PKI armazenadas em `/persist/etc/secureboot`
- Módulos NVIDIA assinados para compatibilidade

### SSH

- Autenticação por senha desabilitada por padrão
- Login root desabilitado
- Chaves do servidor em `/persist/etc/ssh/`

## Referências e Inspirações

- [Fedora Silverblue](https://silverblue.fedoraproject.org/)
- [Project Bluefin](https://projectbluefin.io/)
- [Erase Your Darlings](https://grahamc.com/blog/erase-your-darlings/)
- [NixOS Impermanence](https://github.com/nix-community/impermanence)
- [Disko](https://github.com/nix-community/disko)
- [Btrfs on NixOS](https://nixos.wiki/wiki/Btrfs)
- [Arch Wiki — Btrfs](https://wiki.archlinux.org/title/Btrfs)
- [Lanzaboote](https://github.com/nix-community/lanzaboote)
- [Repositório antigo](https://github.com/lbssousa/nixos-config-old)
