# nixos-config

Configuração pessoal do NixOS baseada em Flakes, com ZFS, particionamento declarativo (disko), sistema efêmero (impermanence), swap híbrida e ambiente GNOME similar ao Fedora Silverblue/Bluefin.

## 🎯 Características

- ✅ **Nix Flakes**: Configuração reproduzível e declarativa
- ✅ **Disko**: Particionamento declarativo de disco
- ✅ **LUKS + LVM**: Criptografia completa do disco
- ✅ **ZFS**: Sistema de arquivos moderno com compressão zstd e snapshots
- ✅ **Impermanence**: Sistema efêmero, limpo a cada boot via rollback ZFS
- ✅ **Swap híbrida**: zram + swap em disco para máxima performance
- ✅ **GNOME**: Ambiente desktop moderno com suporte a Wayland
- ✅ **Flatpak**: Aplicações instaladas system-wide sem senha (como Silverblue)
- ✅ **Podman + Distrobox**: Containers rootless (experiência Silverblue)
- ✅ **Home Manager**: Gerenciamento de configurações de usuário
- ✅ **Homebrew**: Ferramentas CLI via Linuxbrew
- ✅ **Brave**: Navegador padrão instalado via Nix
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
├── disko.nix                 # Template ZFS de particionamento (LUKS+LVM+ZFS)
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
│   ├── audio.nix             # PipeWire
│   ├── boot.nix              # systemd-boot/lanzaboote + Plymouth (flicker-free)
│   ├── common.nix            # Configurações básicas (locale, nix, ZFS)
│   ├── containers.nix        # Podman rootless + Distrobox
│   ├── desktop.nix           # GNOME, Flatpak, Brave, fontes
│   ├── homebrew.nix          # Suporte ao Linuxbrew/Homebrew
│   ├── impermanence.nix      # Rollback ZFS + diretórios persistentes
│   ├── packages.nix          # Pacotes essenciais (Neovim, Helix, etc.)
│   ├── printing.nix          # Impressora Epson ESC-P/R + ecbd.service
│   ├── shells.nix            # Bash, Fish, Zsh (padrão: Zsh)
│   ├── ssh.nix               # Servidor SSH
│   └── users.nix             # Configuração base de usuários
├── scripts/
│   └── install.sh            # Script de instalação automatizada
├── users/                    # Configurações de usuário (NÃO commitadas)
│   └── skeleton.nix          # Template para criar novo usuário
├── .gitignore                # Ignorar arquivos sensíveis
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

# 3. Executar o script de instalação (guia passo a passo interativo)
bash scripts/install.sh

# Para ver todas as opções disponíveis:
bash scripts/install.sh --help
```

**Instalação não-interativa (exemplo completo):**

```bash
bash scripts/install.sh \
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
# Atualizar flake inputs
sudo nix flake update /etc/nixos

# Rebuildar sistema
sudo nixos-rebuild switch --flake /etc/nixos#barbudus
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

3. Importe o arquivo no `hosts/<host>/configuration.nix`:
   ```nix
   imports = [
     # ...outros módulos...
     ./../../users/seu-usuario.nix
   ];
   ```

4. Rebuilde o sistema:
   ```bash
   sudo nixos-rebuild switch --flake /etc/nixos#barbudus
   ```

## 📱 Instalando Flatpaks

Com a configuração de polkit incluída, usuários do grupo `wheel` podem instalar Flatpaks system-wide sem senha:

```bash
# Adicionar repositório Flathub
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# Instalar aplicativos recomendados
flatpak install flathub org.gnome.Papers          # Visualizador de PDF
flatpak install flathub app.devsuite.Ptyxis       # Terminal
flatpak install flathub io.github.bazaar_cabinet.Bazaar  # Loja de apps
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
- [ZFS on NixOS](https://nixos.wiki/wiki/ZFS)
