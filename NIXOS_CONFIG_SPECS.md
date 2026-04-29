# Especificações do Projeto NixOS Config

Este documento registra os requisitos e especificações para a configuração do NixOS deste repositório.
Serve como referência para manutenção e extensão futura.

## Propósito Geral

Propiciar uma experiência de uso similar à do Fedora Silverblue ou do projeto Bluefin, com:
- Sistema base enxuto e declarativo via Nix Flakes
- Uso massivo de Flatpaks para aplicações GUI
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

### Raiz efêmera (tmpfs)

A raiz do sistema (`/`) é um **tmpfs** — filesystem inteiramente em RAM. Isso significa:
- É sempre limpa a cada boot (sem dados acumulados, sem rollback necessário)
- Qualquer arquivo gravado em `/` é perdido ao reiniciar (exceto os preservados em `/persist`)
- Simples e confiável: não requer snapshot, rollback ou configuração de initrd

**Opções de montagem:** `defaults,size=50%,mode=755`

### Subvolumes Btrfs

A convenção `@` é compatível com ferramentas como Timeshift e amplamente adotada pela comunidade.

| Subvolume | Mountpoint | Características |
|-----------|-----------|-----------------|
| `@home` | `/home` | Preservado — diretórios de usuário |
| `@nix` | `/nix` | Preservado — Nix store (essencial) |
| `@persist` | `/persist` | Preservado — dados persistentes do sistema (impermanence) |
| `@log` | `/var/log` | Preservado — logs do sistema (sem compressão) |
| `@containers` | `/var/lib/containers` | Preservado — dados de containers |
| `@flatpak` | `/var/lib/flatpak` | Preservado — aplicações Flatpak |
| `@snapshots` | `/.snapshots` | Preservado — snapshots Btrfs para backup |

**Opções de montagem globais:**
- `compress=zstd` (exceto `@log`: sem compressão)
- `noatime`

**Impermanência — estratégia:**
- A raiz tmpfs é sempre "limpa" ao boot — não requer snapshot ou rollback
- Arquivos importantes são preservados em `/persist` via bind mounts (impermanence)
- O `/persist` é um subvolume Btrfs persistente entre boots

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

### GNOME e KDE Plasma

- Seleção de desktop por variante do flake (`<host>-gnome` ou `<host>-plasma`)
- GNOME usa GDM (Wayland) e KDE usa SDDM + Plasma 6 (Wayland)
- Aplicações Flatpak comuns são compartilhadas entre os dois ambientes
- No perfil GNOME, apps padrão são substituídos por Brave/Ptyxis/Flatpaks

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
- Configurações de usuário em `users/<usuario>.nix` (commitados)

## Impermanence (Sistema Efêmero)

### Como Funciona

1. A raiz do sistema (`/`) é um **tmpfs** — filesystem em RAM, sempre vazio ao boot
2. Não há rollback, snapshot ou serviço de initrd necessário
3. Arquivos e diretórios importantes são preservados via bind mounts de `/persist`
4. `/persist` é um subvolume Btrfs persistente (sobrevive a qualquer número de reboots)
5. `/home`, `/nix`, `/var/log`, `/var/lib/containers` e `/var/lib/flatpak` também são subvolumes Btrfs persistentes

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
