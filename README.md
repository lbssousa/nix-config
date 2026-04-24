# nixos-config

Configuração pessoal do NixOS baseada em Flakes, com Btrfs, particionamento declarativo (disko), sistema efêmero (impermanence), swap híbrida e ambiente GNOME similar ao Fedora Silverblue/Bluefin.

## 🎯 Características

- ✅ **Nix Flakes**: Configuração reproduzível e declarativa
- ✅ **Disko**: Particionamento declarativo de disco
- ✅ **LUKS + LVM**: Criptografia completa do disco
- ✅ **Btrfs**: Sistema de arquivos moderno com compressão zstd, subvolumes e snapshots
- ✅ **Impermanence**: Sistema efêmero com tmpfs na raiz — limpo a cada boot
- ✅ **Swap híbrida**: zram + swap em disco para máxima performance
- ✅ **GNOME**: Ambiente desktop moderno com suporte a Wayland
- ✅ **Flatpak**: Aplicações instaladas system-wide automaticamente após o boot (como Silverblue)
- ✅ **Podman + Distrobox**: Containers rootless (experiência Silverblue)
- ✅ **Home Manager**: Gerenciamento de configurações de usuário
- ✅ **Homebrew**: Ferramentas CLI via Linuxbrew
- ✅ **Brave**: Navegador padrão instalado via Nix
- ✅ **Ptyxis**: Terminal moderno instalado via Nix (substitui GNOME Console)
- ✅ **Multi-host**: Configurações específicas para cada máquina
- ✅ **Modular**: Módulos compartilhados para fácil manutenção
- ✅ **Secure Boot**: Suporte via lanzaboote (barbudus)

## 🖥️ Hosts Suportados

### barbudus

- **Hardware**: Dell Inspiron 14 5490
- **CPU**: Intel i5-10210U
- **RAM**: 16 GB
- **GPU**: Intel UHD 620 + NVIDIA GeForce MX230 (PRIME offload)
- **Swap**: 20 GB em disco + 8 GB zram
- **Extras**: NVIDIA drivers + Secure Boot, sensor de impressão digital Goodix

### bigodon

- **Hardware**: Morefine M6 Mini-PC
- **CPU**: Intel N200
- **RAM**: 16 GB
- **GPU**: Intel UHD Graphics (integrada)
- **Swap**: 20 GB em disco + 8 GB zram

## 📁 Estrutura do Projeto

```
.
├── flake.nix                 # Entrada principal do Flake
├── flake.lock                # Lockfile das dependências
├── home.nix                  # Configuração base do Home Manager
├── disko.nix                 # Template Btrfs de particionamento (LUKS+LVM+Btrfs)
├── hosts/                    # Configurações específicas por host
│   ├── barbudus/
│   │   ├── configuration.nix        # Config específica (NVIDIA, fprintd, etc.)
│   │   ├── hardware-configuration.nix # Hardware + disko + zram
│   │   └── disko.nix                # Parâmetros do disko para este host
│   └── bigodon/
│       ├── configuration.nix
│       ├── hardware-configuration.nix
│       └── disko.nix
├── modules/                  # Módulos compartilhados
│   ├── system/               # Módulos de sistema
│   │   ├── audio/
│   │   │   └── audio.nix     # PipeWire
│   │   ├── boot/
│   │   │   └── boot.nix      # systemd-boot/lanzaboote + Plymouth (flicker-free)
│   │   ├── containers/
│   │   │   └── containers.nix # Podman rootless + Distrobox
│   │   ├── core/
│   │   │   ├── common.nix    # Configurações básicas (locale, nix, Btrfs)
│   │   │   └── impermanence.nix # Raiz tmpfs + diretórios persistentes (/persist)
│   │   ├── desktop/
│   │   │   └── desktop.nix   # GNOME, Flatpak, fontes, instalação automática de apps
│   │   ├── hardware/
│   │   │   └── printing.nix  # Impressora Epson ESC-P/R + ecbd.service
│   │   ├── network/
│   │   │   ├── ssh.nix       # Servidor SSH
│   │   │   └── wifi.nix      # Redes Wi-Fi declarativas (NetworkManager)
│   │   ├── security/
│   │   │   └── tpm2.nix      # TPM2 para desbloqueio automático do LUKS
│   │   ├── shell/
│   │   │   └── shells.nix    # Bash, Fish, Zsh (padrão: Zsh)
│   │   ├── tools/
│   │   │   ├── homebrew.nix  # Suporte ao Linuxbrew/Homebrew
│   │   │   └── packages.nix  # Pacotes essenciais (Neovim, Helix, etc.)
│   │   └── users/
│   │       └── users.nix     # Configuração base de usuários
│   └── user/                 # Módulos de usuário (Home Manager)
│       └── apps/
│           └── brave.nix     # Brave Browser via nixpkgs (alternativa ao Flatpak)
├── scripts/
│   ├── install.sh            # Script de instalação automatizada
│   ├── update.sh             # Atualizar flake inputs + nixos-rebuild switch
│   ├── enroll-tpm2.sh        # Configurar desbloqueio LUKS via TPM2
│   └── setup-secureboot.sh   # Configurar Secure Boot + assinar módulos (barbudus)
├── users/                    # Configurações de usuário
│   └── skeleton.nix          # Template para criar novo usuário
├── .gitignore                # Ignorar arquivos temporários e chaves
├── INSTALLATION.md           # Guia de instalação detalhado
├── NIXOS_CONFIG_SPECS.md     # Especificações do projeto
└── README.md                 # Este arquivo
```

## 🚀 Início Rápido

### Pré-requisitos

- ISO do NixOS (minimal ou graphical): https://nixos.org/download.html
- USB bootável criado com a ISO

### Instalação

Veja o [Guia de Instalação Completo](INSTALLATION.md) para instruções detalhadas.

**Instalação automatizada com o script:**

```bash
# 1. Boot no USB do NixOS

# 2. Clonar este repositório
nix-shell -p git
git clone https://github.com/lbssousa/nixos-config.git /tmp/nixos-config
cd /tmp/nixos-config

# 3. Executar o script de instalação como root (guia passo a passo interativo)
sudo bash scripts/install.sh

# Para ver todas as opções disponíveis:
sudo bash scripts/install.sh --help
```

**Instalação não-interativa (exemplo completo):**

```bash
sudo bash scripts/install.sh \
  --host barbudus \
  --disk /dev/nvme0n1 \
  --user "joao:cavalo:sudo" \
  --non-interactive
```

**Instalação manual (passo a passo):**

```bash
# 1. Boot no USB do NixOS

# 2. Habilitar flakes
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf

# 3. Clonar este repositório
nix-shell -p git
git clone https://github.com/lbssousa/nixos-config.git /tmp/nixos-config
cd /tmp/nixos-config

# 4. Ajustar device no disko.nix do host
# Para barbudus:
nano hosts/barbudus/disko.nix  # Ajuste /dev/nvme0n1 se necessário
# Para bigodon:
nano hosts/bigodon/disko.nix

# 5. Particionar e instalar (⚠️ APAGA TODOS OS DADOS DO DISCO!)
# Cria: raiz tmpfs + subvolumes Btrfs (@home, @nix, @persist, @log, ...)
HOST=barbudus  # ou bigodon
sudo nix run github:nix-community/disko -- --mode disko ./hosts/$HOST/disko.nix

# 6. Instalar o NixOS
sudo nixos-install --flake .#$HOST

# 7. Definir senha do usuário
sudo nixos-enter --root /mnt
passwd seu-usuario
exit

# 8. Reiniciar
sudo reboot
```

### Atualização

```bash
# Atualizar flake inputs e rebuildar o sistema (recomendado):
sudo bash scripts/update.sh

# Apenas atualizar flake inputs (sem rebuild):
sudo bash scripts/update.sh --update-only

# Apenas rebuild (sem atualizar inputs):
sudo bash scripts/update.sh --rebuild-only
```

### Rollback

```bash
# Listar gerações disponíveis
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# Voltar para a geração anterior
sudo nixos-rebuild switch --rollback
```

## 🔧 Adicionando um Usuário

1. Copie o template de usuário:
   ```bash
   cp users/skeleton.nix users/seu-usuario.nix
   ```

2. Edite `users/seu-usuario.nix` e substitua `skeleton` pelo nome do usuário.

3. Adicione o arquivo ao índice do git:
   ```bash
   git add users/seu-usuario.nix
   ```

4. Importe o arquivo no `hosts/<host>/configuration.nix`:
   ```nix
   imports = [
     # ...outros módulos...
     ./../../users/seu-usuario.nix
   ];
   ```

5. Rebuilde o sistema:
   ```bash
   sudo nixos-rebuild switch --flake /etc/nixos#barbudus
   ```

## 📡 Configurando Redes Wi-Fi

Edite `modules/system/network/wifi.nix` para declarar redes Wi-Fi via NetworkManager.
O hash PBKDF2 da senha (mais seguro que texto simples) pode ser gerado com:

```bash
nix-shell -p wpa_supplicant --run "wpa_passphrase NomeDaRede SenhaAqui"
```

Use o valor do campo `psk=` (sem o `#`) como valor de `psk` no perfil da conexão.

## 📱 Instalando Flatpaks

Os Flatpaks padrão do sistema são **instalados automaticamente** via um serviço
systemd (`install-system-flatpaks`) na primeira inicialização, ou sempre que a
lista de aplicativos for alterada. Não é necessária nenhuma ação manual.

O repositório Flathub é configurado automaticamente. Os aplicativos instalados
incluem: Bazaar (loja de apps), Papers (PDF), Mission Center (monitor), e muitos
outros apps GNOME. Brave Browser e Ptyxis são instalados via Nix.

Para instalar aplicativos adicionais manualmente:

```bash
# Usuários do grupo 'wheel' podem instalar Flatpaks system-wide sem senha
flatpak install flathub <app-id>

# Exemplo:
flatpak install flathub org.gimp.GIMP
```

## 🔒 Configuração Pós-Instalação

### Secure Boot (apenas barbudus)

Após o primeiro boot, com o Secure Boot **desativado** na UEFI (Setup Mode):

```bash
sudo bash scripts/setup-secureboot.sh
```

Em seguida, ative o Secure Boot na UEFI e reinicie.

### Desbloqueio automático LUKS via TPM2

Após o primeiro boot bem-sucedido:

```bash
sudo bash scripts/enroll-tpm2.sh
```

## 📚 Documentação

- **[INSTALLATION.md](INSTALLATION.md)**: Guia completo de instalação
- **[NIXOS_CONFIG_SPECS.md](NIXOS_CONFIG_SPECS.md)**: Especificações e requisitos do projeto

## 🔗 Referências

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Disko](https://github.com/nix-community/disko)
- [Impermanence](https://github.com/nix-community/impermanence)
- [Home Manager](https://github.com/nix-community/home-manager)
- [NixOS Hardware](https://github.com/NixOS/nixos-hardware)
- [Lanzaboote (Secure Boot)](https://github.com/nix-community/lanzaboote)
- [Erase Your Darlings (impermanence concept)](https://grahamc.com/blog/erase-your-darlings/)
- [Btrfs on NixOS](https://nixos.wiki/wiki/Btrfs)
- [Arch Wiki — Btrfs](https://wiki.archlinux.org/title/Btrfs)
