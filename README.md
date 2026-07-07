# nixos-config

Configuração pessoal do NixOS baseada em Flakes, com Btrfs, particionamento declarativo (disko), sistema efêmero (preservation), swap híbrida e desktop GNOME.

## 🎯 Características

- ✅ **Nix Flakes**: Configuração reproduzível e declarativa
- ✅ **Disko**: Particionamento declarativo de disco
- ✅ **LUKS + LVM**: Criptografia completa do disco
- ✅ **Btrfs**: Sistema de arquivos moderno com compressão zstd, subvolumes e snapshots
- ✅ **Preservation**: Sistema efêmero com tmpfs na raiz — limpo a cada boot
- ✅ **Swap híbrida**: zram + swap em disco para máxima performance
- ✅ **Desktop GNOME**: GNOME com apps e fontes configurados declarativamente via Nix
- ✅ **Flatpak**: Apenas apps sem equivalente no nixpkgs (DistroShelf, Ignition, Warehouse, Bazaar, Flatseal) instalados declarativamente via nix-flatpak
- ✅ **Podman + Distrobox**: Containers rootless (experiência Silverblue)
- ✅ **Home Manager**: Gerenciamento de configurações de usuário
- ✅ **Brave**: Navegador padrão instalado via Nix
- ✅ **Ghostty**: Terminal moderno via Nix, com perfil sem decorações para PaperWM/quake-terminal
- ✅ **Multi-host**: Configurações específicas para cada máquina
- ✅ **Modular**: Módulos compartilhados para fácil manutenção
- ✅ **Secure Boot**: Suporte via Limine (barbudus)
- ✅ **YubiKey U2F**: sudo, run0 e pkexec autenticados por chave de hardware; senha como fallback quando a YubiKey estiver ausente
- ✅ **git-crypt**: Criptografia seletiva de arquivos sensíveis no repositório

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

```text
.
├── flake.nix                 # Entrada principal do Flake
├── flake.lock                # Lockfile das dependências
├── dendritic/                # Módulos de topo (padrão dendritic)
│   ├── imports.nix           # Import automático de todos os módulos dendríticos
│   ├── options.nix           # Opções do namespace `dendritic.*`
│   ├── data/
│   │   ├── hosts.nix         # Inventário de hosts (sistema, desktop padrão, módulos extras)
│   │   └── users.nix         # Inventário de usuários do sistema/home
│   ├── features/
│   │   ├── local-overlay.nix # Overlay local (importa overlays/default.nix)
│   │   └── nixos-modules.nix # Lista de módulos NixOS compartilhados e módulos de usuários
│   └── flake/
│       ├── nixos-configurations.nix # Geração das saídas nixosConfigurations
│       └── disko-configurations.nix # Geração das saídas diskoConfigurations
├── disko.nix                 # Template Btrfs de particionamento (LUKS+LVM+Btrfs)
├── home/                     # Configurações Home Manager (módulo NixOS, aplicadas no rebuild)
│   ├── common.nix            # Config HM base — aplicada a todos os usuários
│   └── users/                # Customizações por usuário
│       └── abutre/
│           └── home.nix      # Config específica do abutre (p10k, git, Bitwarden)
├── hosts/                    # Configurações específicas por host (NixOS)
│   ├── barbudus/
│   │   ├── configuration.nix        # Config específica (NVIDIA, fprintd, etc.)
│   │   ├── hardware-configuration.nix # Hardware + disko + zram
│   │   └── disko.nix                # Parâmetros do disko para este host
│   └── bigodon/
│       ├── configuration.nix
│       ├── hardware-configuration.nix
│       └── disko.nix
├── modules/                  # Módulos compartilhados (sistema e Home Manager)
│   ├── home/                 # Módulos Home Manager reutilizáveis
│   │   ├── apps/
│   │   │   ├── nix-validation.nix
│   │   │   ├── browsers/
│   │   │   │   ├── brave.nix
│   │   │   │   ├── firefox.nix
│   │   │   │   └── google-chrome.nix
│   │   │   ├── security/
│   │   │   │   ├── bitwarden.nix  # SSH agent + integração Zsh
│   │   │   │   ├── keepassxc.nix
│   │   │   │   └── yubikey.nix
│   │   │   └── terminals/
│   │   │       ├── ghostty.nix    # Terminal padrão, perfis c/ e s/ decorações
│   │   │       └── tmux.nix
│   │   └── desktop/
│   │       └── ibus-compose.nix
│   └── system/               # Módulos de sistema (nixos-rebuild)
│       ├── audio/
│       │   └── audio.nix     # PipeWire
│       ├── boot/
│       │   └── boot.nix      # systemd-boot/Limine + Plymouth (flicker-free)
│       ├── containers/
│       │   └── containers.nix # Podman rootless + Distrobox
│       ├── core/
│       │   ├── common.nix          # Configurações básicas (locale, nix, Btrfs)
│       │   ├── preservation.nix    # Raiz tmpfs + diretórios persistentes (/persist)
│       │   └── preservation-zfs.nix # Variante ZFS com rollback no initrd
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
│       │   └── packages.nix  # Pacotes essenciais (Neovim, Helix, home-manager, just, etc.)
│       └── users/
│           └── users.nix     # Contas de usuário, grupos e política de sudo
├── overlays/
│   └── default.nix           # Overlay local: pacotes personalizados adicionados ao nixpkgs
├── pkgs/                     # Pacotes customizados (fora do nixpkgs oficial)
│   ├── epson-printer-utility/
│   ├── gregorio-lsp/
│   ├── gregolint/
│   ├── tree-sitter-gregorio/
│   └── zed-gregorio/
├── justfile                  # Receitas Just para switch, HM e manutenção
├── scripts/
│   ├── install.sh            # Script de instalação automatizada
│   ├── update.sh             # Atualizar flake inputs + nixos-rebuild switch
│   ├── enroll-tpm2.sh        # Configurar desbloqueio LUKS via TPM2
│   └── setup-secureboot.sh   # Configurar Secure Boot + assinar módulos (barbudus)
├── users/                    # Definições de contas de usuário NixOS
│   ├── skeleton.nix          # Template para criar novo usuário
│   ├── abutre.nix            # Conta do sistema do abutre
│   ├── surubi.nix            # Conta do sistema da surubi
│   └── ...                   # Demais usuários
├── .gitignore                # Ignorar arquivos temporários e chaves
├── INSTALLATION.md           # Guia de instalação detalhado
├── NIXOS_CONFIG_SPECS.md     # Especificações do projeto
└── README.md                 # Este arquivo
```

### Integração NixOS + Home Manager

O Home Manager é integrado como módulo NixOS — **um único `nixos-rebuild switch` aplica tanto
as configurações do sistema quanto as de todos os usuários gerenciados**. Não há um plano separado
de Home Manager: tudo é acionado pelo mesmo rebuild.

| Diretórios | O que contém |
| ---------- | ------------ |
| `dendritic/`, `hosts/`, `modules/system/`, `users/` | Configurações de sistema (NixOS) |
| `home/`, `modules/home/` | Configurações de usuário (Home Manager, aplicadas via NixOS) |

- Qualquer mudança em `home/` é aplicada no próximo `sudo nixos-rebuild switch` (ou `just switch`).
- Ambos usam o mesmo `nixpkgs` (pinado via `flake.lock`).

## 🚀 Início Rápido

### Pré-requisitos

- ISO do NixOS (minimal ou graphical): [https://nixos.org/download.html](https://nixos.org/download.html)
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
  --user "cavalo:sudo" \
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

### Switch do sistema (inclui Home Manager)

```bash
# Via Just — eleva automaticamente com run0 (polkit/YubiKey):
just switch                  # host atual
just switch barbudus         # host específico

# Ou via alias de shell (disponível após o primeiro switch):
nrs   # nixos-rebuild switch (NixOS + HM)
nrb   # nixos-rebuild boot   (aplica no próximo boot)
nru   # atualiza inputs + switch
```

> As configurações de Home Manager de todos os usuários são aplicadas automaticamente
> a cada rebuild do sistema — não é necessário nenhum comando adicional.

### Aliases de shell (bash/zsh)

Definidos em `home/common.nix` e disponíveis em sessões interativas após o primeiro `just switch`.
Todos os aliases NixOS usam `run0` para elevação de privilégio via polkit/YubiKey
(sem prompt de senha), e repassam `SSH_AUTH_SOCK` para que o `nixos-rebuild` acesse
entradas de flake protegidas por SSH (ex.: `nix-secrets`).
Como o Home Manager é um módulo NixOS, todo rebuild aplica NixOS e HM juntos.

| Alias | Efeito |
|-------|--------|
| `nrs` | `nixos-rebuild switch` — aplica NixOS + HM e ativa imediatamente |
| `nrb` | `nixos-rebuild boot` — prepara o próximo boot, sessão atual inalterada |
| `nru` | `nix flake update` + `nixos-rebuild switch` — atualiza inputs e aplica |
| `hmn` | `home-manager news` — exibe o changelog do HM desde a última geração |

A função auxiliar `_nix_cfg()` resolve o caminho do flake automaticamente:
`/etc/nixos` em sistemas implantados, ou `$PROJECTS/lbssousa/nix-config`
em checkouts de desenvolvimento. O wrapper `just()` aponta sempre para
`$(_nix_cfg)/justfile`, então `just switch` funciona em qualquer diretório.

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

4. Inclua o usuário no inventário do sistema:

   > Com arquitetura dendrítica, a inclusão é centralizada no inventário.
   > Adicione o login em `dendritic/data/users.nix`.

   Exemplo:

   ```nix
   config.dendritic.users = [
     "abutre"
     "surubi"
     "coruja"
     "camelo"
     "cavalo"
     "macaco"
     "seu-usuario"
   ];
   ```

5. Rebuilde o sistema:

   ```bash
   just switch
   ```

### 2. Configurar o Home Manager do usuário (opcional)

Para uma configuração HM personalizada (além da `home/common.nix` padrão):

1. Crie o arquivo de customização do usuário:

   ```bash
   mkdir -p home/users/seu-usuario
   cp home/users/abutre/home.nix home/users/seu-usuario/home.nix
   # Edite conforme necessário
   ```

2. `dendritic/flake/home-nixos-module.nix` detecta automaticamente o arquivo
   `home/users/<username>/home.nix` e o importa para o usuário correspondente.

3. Aplique com um rebuild normal do sistema:

   ```bash
   just switch
   ```

> Usuários sem customização continuam recebendo apenas `home/common.nix` automaticamente.

## 🖥️ Adicionando um Novo Host

1. Crie o diretório `hosts/<novo-host>/` com os arquivos:
   - `configuration.nix` — configurações específicas do host (sem lista de imports compartilhados)
   - `hardware-configuration.nix` — gerado por `nixos-generate-config`
   - `disko.nix` — parâmetros de particionamento (copie de um host existente)

2. Adicione o host no inventário dendrítico em `dendritic/data/hosts.nix`:

   ```nix
   config.dendritic.hosts = {
     # ...hosts existentes...
     novo-host = {
       system = "x86_64-linux";
       extraNixosModules = [ ];
     };
   };
   ```

3. Adicione os arquivos do host ao índice do git (`git add`) antes de avaliar o flake,
   pois flakes ignoram arquivos não rastreados.

## 📡 Configurando Redes Wi-Fi

Edite `modules/system/network/wifi.nix` para declarar redes Wi-Fi via NetworkManager.
O hash PBKDF2 da senha (mais seguro que texto simples) pode ser gerado com:

```bash
nix-shell -p wpa_supplicant --run "wpa_passphrase NomeDaRede SenhaAqui"
```

Use o valor do campo `psk=` (sem o `#`) como valor de `psk` no perfil da conexão.

## 🔑 Criptografia de Arquivos (git-crypt)

Este repositório suporta **git-crypt** para criptografar arquivos sensíveis rastreados pelo git.
Arquivos marcados com o filtro `git-crypt` aparecem como texto legível para colaboradores com a
chave e como dados binários cifrados para os demais. O `git-crypt` está disponível em todos os
sistemas gerenciados por este repositório.

### Desbloquear o repositório após clonar

Se o repositório tiver arquivos criptografados, desbloqueie-os antes de qualquer build:

```bash
# Com chave simétrica (arquivo exportado):
git-crypt unlock /caminho/para/git-crypt.key

# Com chave GPG (chave configurada no keyring):
git-crypt unlock
```

> ⚠️ **Importante para Nix flakes**: arquivos cifrados não desbloqueados aparecem como dados
> binários no repositório. O avaliador Nix tentará parseá-los como código e falhará com um
> erro de sintaxe. Sempre execute `git-crypt unlock` antes de `just switch` ou
> `nixos-rebuild`.

### Adicionar arquivos criptografados ao repositório

```bash
# 1. Inicializar git-crypt (apenas uma vez por repositório):
git-crypt init

# 2. Exportar a chave simétrica para backup seguro (guarde fora do repositório):
git-crypt export-key ~/git-crypt-nixos-config.key

# 3. Marcar arquivos para criptografia via .gitattributes:
echo "caminho/para/arquivo filter=git-crypt diff=git-crypt" >> .gitattributes
git add .gitattributes caminho/para/arquivo
git commit -m "Adicionar arquivo secreto criptografado"
# O arquivo é criptografado automaticamente no push e no clone por quem não tem a chave.
```

## 📱 Flatpaks

A maioria dos aplicativos do desktop GNOME é instalada diretamente via Nix
(`environment.systemPackages`). O Flatpak é mantido apenas para os cinco apps
sem equivalente adequado no nixpkgs:

| App Flatpak | Descrição |
|-------------|-----------|
| `com.github.tchx84.Flatseal` | Gerenciador de permissões Flatpak |
| `com.ranfdev.DistroShelf` | Gerenciador de distros em contêineres |
| `io.github.flattool.Ignition` | Gerenciador de autostart de Flatpaks |
| `io.github.flattool.Warehouse` | Gerenciador de apps Flatpak |
| `io.github.kolunmi.Bazaar` | Loja de apps GNOME |

Esses Flatpaks são **instalados automaticamente** na primeira inicialização com
internet disponível (via serviço `flatpak-managed-install` do nix-flatpak).
Nenhuma ação manual é necessária. Atualizações automáticas diárias também estão
configuradas.

Para instalar aplicativos adicionais manualmente:

```bash
# Usuários do grupo 'wheel' podem instalar Flatpaks system-wide sem senha
flatpak install flathub <app-id>

# Exemplo:
flatpak install flathub org.gimp.GIMP
```

## 🔒 Configuração Pós-Instalação

### Registro do YubiKey U2F (pamu2fcfg)

> 💡 **Recomendado para usuários do grupo `wheel`**: quando `/persist/etc/u2f-mappings` existe
> e contém a entrada do usuário, `sudo`, `run0` e `pkexec` exigem toque na YubiKey. Se o arquivo
> não existir ou o usuário não tiver entrada nele, o PAM cai automaticamente para autenticação
> por **senha** — sem lockout.

Este passo deve ser executado **durante a instalação**, antes do primeiro reboot. Veja o
[passo 10 do guia de instalação](INSTALLATION.md) para as instruções completas.

Se o passo foi pulado, o sistema ainda funcionará normalmente via senha. Para registrar a
YubiKey depois do primeiro boot, consulte a seção
[Registrar YubiKey após o primeiro boot](INSTALLATION.md#-solução-de-problemas) no guia de instalação.

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
- **[modules/home/apps/terminals/README.md](modules/home/apps/terminals/README.md)**: Atalhos de teclado do tmux

## 🔗 Referências

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Disko](https://github.com/nix-community/disko)
- [Preservation](https://github.com/nix-community/preservation)
- [Home Manager](https://github.com/nix-community/home-manager)
- [NixOS Hardware](https://github.com/NixOS/nixos-hardware)
- [Limine Bootloader](https://github.com/limine-bootloader/limine)
- [nix-flatpak](https://github.com/gmodena/nix-flatpak)
- [Ghostty](https://ghostty.org/)
- [Erase Your Darlings (sistema efêmero)](https://grahamc.com/blog/erase-your-darlings/)
- [Btrfs on NixOS](https://nixos.wiki/wiki/Btrfs)
- [Arch Wiki — Btrfs](https://wiki.archlinux.org/title/Btrfs)
- [EmergentMind/nix-config](https://github.com/EmergentMind/nix-config) — referência de organização de repositório NixOS
