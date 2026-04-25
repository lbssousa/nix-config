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
├── disko.nix                 # Template Btrfs de particionamento (LUKS+LVM+Btrfs)
├── home/                     # Configurações Home Manager (independentes do sistema)
│   ├── common.nix            # Config HM base — aplicada a todos os usuários
│   ├── modules/              # Módulos HM reutilizáveis por usuário
│   │   └── apps/
│   │       └── brave.nix     # Brave Browser via nixpkgs (alternativa ao Flatpak)
│   └── users/                # Customizações por usuário
│       └── laercio/
│           └── home.nix      # Config específica do laercio (p10k, git, Bitwarden)
├── hosts/                    # Configurações específicas por host (NixOS)
│   ├── barbudus/
│   │   ├── configuration.nix        # Config específica (NVIDIA, fprintd, etc.)
│   │   ├── hardware-configuration.nix # Hardware + disko + zram
│   │   └── disko.nix                # Parâmetros do disko para este host
│   └── bigodon/
│       ├── configuration.nix
│       ├── hardware-configuration.nix
│       └── disko.nix
├── modules/                  # Módulos NixOS compartilhados
│   └── system/               # Módulos de sistema (nixos-rebuild)
│       ├── audio/
│       │   └── audio.nix     # PipeWire
│       ├── boot/
│       │   └── boot.nix      # systemd-boot/lanzaboote + Plymouth (flicker-free)
│       ├── containers/
│       │   └── containers.nix # Podman rootless + Distrobox
│       ├── core/
│       │   ├── common.nix    # Configurações básicas (locale, nix, Btrfs)
│       │   └── impermanence.nix # Raiz tmpfs + diretórios persistentes (/persist)
│       ├── desktop/
│       │   └── desktop.nix   # GNOME, Flatpak, fontes, instalação automática de apps
│       ├── hardware/
│       │   └── printing.nix  # Impressora Epson ESC-P/R + ecbd.service
│       ├── network/
│       │   ├── ssh.nix       # Servidor SSH
│       │   └── wifi.nix      # Redes Wi-Fi declarativas (NetworkManager)
│       ├── security/
│       │   └── tpm2.nix      # TPM2 para desbloqueio automático do LUKS
│       ├── shell/
│       │   └── shells.nix    # Shells disponíveis no sistema (Bash, Fish, Zsh)
│       ├── tools/
│       │   ├── lbnix.nix     # Wrapper lbnix (switch, home, update, gc, diff...)
│       │   └── packages.nix  # Pacotes essenciais (Neovim, Helix, home-manager, etc.)
│       └── users/
│           └── users.nix     # Contas de usuário, grupos e política de sudo
├── scripts/
│   ├── install.sh            # Script de instalação automatizada
│   ├── update.sh             # Atualizar flake inputs + nixos-rebuild switch
│   ├── enroll-tpm2.sh        # Configurar desbloqueio LUKS via TPM2
│   └── setup-secureboot.sh   # Configurar Secure Boot + assinar módulos (barbudus)
├── users/                    # Definições de contas de usuário NixOS
│   ├── skeleton.nix          # Template para criar novo usuário
│   ├── laercio.nix           # Conta do sistema do laercio
│   ├── roberta.nix           # Conta do sistema da roberta
│   └── ...                   # Demais usuários
├── .gitignore                # Ignorar arquivos temporários e chaves
├── INSTALLATION.md           # Guia de instalação detalhado
├── NIXOS_CONFIG_SPECS.md     # Especificações do projeto
└── README.md                 # Este arquivo
```

### Desacoplamento NixOS ↔ Home Manager

A configuração está organizada em dois planos independentes:

| Plano | Diretórios | Comando |
|-------|-----------|---------|
| **Sistema (NixOS)** | `hosts/`, `modules/system/`, `users/` | `sudo nixos-rebuild switch --flake /etc/nixos#<host>` |
| **Usuário (Home Manager)** | `home/` | `home-manager switch --flake /etc/nixos#<usuario>@<host>` |

- Switches de sistema **não** aplicam configurações de home-manager.
- Switches de home-manager **não** exigem rebuild do sistema.
- Ambos usam o mesmo `nixpkgs` (pinado via `flake.lock`).

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
  --user "joao:João Silva:sudo" \
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

### Atualização do sistema

```bash
# Atualizar flake inputs e rebuildar o sistema (recomendado):
sudo bash scripts/update.sh

# Apenas atualizar flake inputs (sem rebuild):
sudo bash scripts/update.sh --update-only

# Apenas rebuild (sem atualizar inputs):
sudo bash scripts/update.sh --rebuild-only
```

### Switch do sistema (NixOS)

```bash
# Rebuild e ativa a configuração do sistema para o host atual:
sudo nixos-rebuild switch --flake /etc/nixos#barbudus   # ou bigodon

# Via lbnix (detecta o host automaticamente):
sudo lbnix switch
```

### Switch do Home Manager (usuário)

```bash
# Aplica a configuração HM do usuário laercio no host barbudus:
home-manager switch --flake /etc/nixos#laercio@barbudus

# Via lbnix (detecta usuário e host automaticamente):
lbnix home

# Especificando usuário e/ou host manualmente:
lbnix home laercio@bigodon
```

> **Primeira vez?** Se `home-manager` ainda não está instalado, use:
> ```bash
> nix run nixpkgs#home-manager -- switch --flake /etc/nixos#laercio@barbudus
> ```

### Rollback

```bash
# Listar gerações disponíveis
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# Voltar para a geração anterior
sudo nixos-rebuild switch --rollback
```

## 🔧 Adicionando um Usuário

### 1. Criar a conta do sistema

1. Copie o template de usuário:
   ```bash
   cp users/skeleton.nix users/seu-usuario.nix
   ```

2. Edite `users/seu-usuario.nix` e substitua `skeleton` pelo nome do usuário.

3. Adicione o arquivo ao índice do git:
   ```bash
   git add users/seu-usuario.nix
   ```

4. Importe o arquivo em cada `hosts/<host>/configuration.nix` desejado:
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

### 2. Configurar o Home Manager do usuário (opcional)

Para uma configuração HM personalizada (além da `home/common.nix` padrão):

1. Crie o arquivo de customização do usuário:
   ```bash
   mkdir -p home/users/seu-usuario
   cp home/users/laercio/home.nix home/users/seu-usuario/home.nix
   # Edite conforme necessário
   ```

2. Adicione entradas no `flake.nix` dentro de `homeConfigurations`:
   ```nix
   // mkHomeAllHosts "seu-usuario" [ ./home/users/seu-usuario/home.nix ]
   ```

3. Aplique:
   ```bash
   home-manager switch --flake /etc/nixos#seu-usuario@barbudus
   ```

> **Usuários sem customização** já possuem entradas automáticas em `homeConfigurations`
> (via `mkHomeAllHosts`), aplicando apenas `home/common.nix`.

## 🖥️ Adicionando um Novo Host

1. Crie o diretório `hosts/<novo-host>/` com os arquivos:
   - `configuration.nix` — importa os módulos de sistema e usuários
   - `hardware-configuration.nix` — gerado por `nixos-generate-config`
   - `disko.nix` — parâmetros de particionamento (copie de um host existente)

2. Adicione o host em `flake.nix`:
   ```nix
   nixosConfigurations = {
     # ...hosts existentes...
     novo-host = mkHost "novo-host" "x86_64-linux" [ ];
   };
   ```

3. Adicione o host em `allHosts` em `flake.nix` para geração automática dos `homeConfigurations`:
   ```nix
   allHosts = {
     barbudus = "x86_64-linux";
     bigodon  = "x86_64-linux";
     novo-host = "x86_64-linux";
   };
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
