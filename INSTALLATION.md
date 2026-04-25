# Guia de Instalação do NixOS

Este guia cobre a instalação do NixOS usando esta configuração baseada em Flakes com Btrfs, disko, impermanence e swap híbrida.

## 📋 Pré-requisitos

1. Baixe a ISO do NixOS: https://nixos.org/download.html
2. Crie um USB bootável com a ISO
3. Boot no USB do NixOS

## 🚀 Instalação

### Script de Instalação Automatizada (`install.sh`)

O repositório inclui o script `scripts/install.sh` que automatiza todos os passos de instalação descritos neste guia. É a forma mais rápida e segura de instalar o sistema.

#### Como usar

```bash
# 1. Boot no USB do NixOS

# 2. Clonar o repositório
nix-shell -p git
git clone https://github.com/lbssousa/nixos-config.git /tmp/nixos-config
cd /tmp/nixos-config

# 3. Executar o script como root (modo interativo — recomendado para a maioria dos casos)
sudo bash scripts/install.sh
```

O script irá guiar você por cada etapa, perguntando as informações necessárias.

#### Opções do script

```
Uso:
  bash scripts/install.sh [--host <hostname>] [--disk <device>]
                          [--user "login:Nome Completo:sudo"]
                          [--user "login2:Nome2:nosudo"] ...
                          [--non-interactive]
                          [--help]

Opções:
  --host            Nome do host NixOS (ex: barbudus, bigodon).
                    Se omitido, é perguntado interativamente.
  --disk            Dispositivo de disco de destino (ex: /dev/nvme0n1, /dev/sda).
                    Se omitido, é perguntado interativamente.
  --user            Usuário no formato "login:Nome Completo:sudo|nosudo".
                    Pode ser repetido para criar múltiplos usuários.
                    "sudo" (padrão) inclui o usuário no grupo wheel (sudo).
                    "nosudo" cria o usuário sem permissão de sudo.
                    Se omitido, é perguntado interativamente.
  --non-interactive Não faz perguntas; falha se informações obrigatórias
                    não forem fornecidas via flags.
  --help, -h        Exibe esta ajuda e sai.
```

Para ver a ajuda diretamente:

```bash
sudo bash scripts/install.sh --help
```

#### Exemplos

**Instalação totalmente interativa** (recomendado para iniciantes):

```bash
sudo bash scripts/install.sh
```

**Instalação não-interativa** (útil para automação ou reinstalações):

```bash
sudo bash scripts/install.sh \
  --host barbudus \
  --disk /dev/nvme0n1 \
  --user "joao:João Silva:sudo" \
  --user "maria:Maria Souza:nosudo" \
  --non-interactive
```

**Pré-selecionar host e disco, mas confirmar usuários interativamente:**

```bash
sudo bash scripts/install.sh --host bigodon --disk /dev/sda
```

#### O que o script faz

1. Habilita Flakes e o cache nix-community para o root no ambiente live
2. Lista hosts e discos disponíveis para seleção
3. Atualiza o `disko.nix` do host com o disco escolhido
4. Particiona e formata o disco com disko (⚠️ apaga todos os dados!)
   - A raiz (`/`) é configurada como tmpfs — limpa automaticamente a cada boot
   - Os dados persistentes ficam em subvolumes Btrfs dedicados
5. Cria arquivos de usuário a partir do skeleton
6. Adiciona os arquivos de usuário ao índice do git (`git add`)
7. Atualiza `configuration.nix` com os imports dos usuários
8. Cria chaves Secure Boot em `/persist/etc/secureboot` (apenas hosts com Lanzaboote)
9. Copia a configuração para `/mnt/etc/nixos` e executa `nixos-install`
10. Copia automaticamente as conexões Wi-Fi do live CD para `/persist/etc/NetworkManager/system-connections`
    — o Wi-Fi já estará configurado no primeiro boot, sem precisar redigitar credenciais
11. Define senhas via `nixos-enter` e copia `/etc/shadow` para `/persist`

### Instalação Manual (passo a passo)

```bash
# Conectar à internet (se necessário)
# Para Wi-Fi via NetworkManager:
nmcli device wifi list
nmcli device wifi connect "SSID" password "senha"

# Definir layout do teclado
loadkeys br-abnt2

# Ativar SSH para instalação remota (opcional)
sudo systemctl start sshd
passwd  # Definir senha temporária para o live environment

# Habilitar Flakes e o cache nix-community temporariamente.
# O cache evita compilar dependências do zero (ex: Rust do lanzaboote)
# e falhas de download do crates.io.
mkdir -p ~/.config/nix
cat >> ~/.config/nix/nix.conf <<EOF
experimental-features = nix-command flakes
extra-substituters = https://nix-community.cachix.org
extra-trusted-public-keys = nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCUSeBs=
EOF
```

### 2. Clonar o repositório

```bash
# Instalar git no live environment
nix-shell -p git

# Clonar a configuração
git clone https://github.com/lbssousa/nixos-config.git /tmp/nixos-config
cd /tmp/nixos-config
```

### 3. Identificar o disco de instalação

```bash
# Listar discos disponíveis
lsblk

# Ou com mais detalhes:
fdisk -l

# Identificar o disco correto (ex: /dev/nvme0n1 para NVMe, /dev/sda para SATA)
```

### 4. Ajustar configuração de disco

Edite o arquivo de disko do host desejado para definir o dispositivo correto:

```bash
# Para barbudus (Dell Inspiron 14 5490):
nano hosts/barbudus/disko.nix

# Para bigodon (Morefine M6):
nano hosts/bigodon/disko.nix
```

Altere `device = "/dev/nvme0n1"` para o disco correto identificado no passo anterior.

### 5. Particionar e formatar o disco

⚠️ **ATENÇÃO**: Este comando IRÁ APAGAR TODOS OS DADOS DO DISCO SELECIONADO!

```bash
# Escolha o host apropriado
HOST=barbudus  # ou bigodon

# Executar disko para particionar e formatar
sudo nix run github:nix-community/disko \
  --option extra-substituters "https://nix-community.cachix.org" \
  --option extra-trusted-public-keys "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCUSeBs=" \
  -- --mode disko ./hosts/$HOST/disko.nix
```

Este comando irá:
1. Criar partições GPT (EFI 512MB + partição LUKS)
2. Configurar criptografia LUKS (será solicitada senha durante o processo)
3. Criar volumes LVM (swap 20GB + volume Btrfs)
4. Configurar a raiz (`/`) como **tmpfs** — limpa automaticamente a cada boot
5. Formatar o volume Btrfs e criar os subvolumes de dados persistentes:
   - `@home` → `/home`
   - `@nix` → `/nix`
   - `@persist` → `/persist`
   - `@log` → `/var/log`
   - `@containers` → `/var/lib/containers`
   - `@flatpak` → `/var/lib/flatpak`
   - `@snapshots` → `/.snapshots`
6. Montar tudo em `/mnt`

### 6. Gerar configuração de hardware (recomendado)

```bash
# Gerar hardware-configuration.nix automático
nixos-generate-config --no-filesystems --root /mnt

# Mesclar com o arquivo do host (ou substituir completamente)
# IMPORTANTE: Mantenha a linha "import ./disko.nix" nos imports
# e as configurações de zramSwap do arquivo original
sudo cp /mnt/etc/nixos/hardware-configuration.nix ./hosts/$HOST/hardware-configuration.nix
```

Após copiar, edite o arquivo para:
1. Manter `import ./disko.nix` nos imports
2. Adicionar as configurações de `zramSwap`
3. Manter `fileSystems."/persist".neededForBoot = true`

### 7. Criar arquivos de usuário

É possível criar **uma ou mais contas de usuário**. Para cada conta, defina o nome de login, o nome completo e se ela terá permissão de **sudo** (grupo `wheel`) ou não.

```bash
# Copiar o template para o(s) usuário(s) desejado(s)
cp users/skeleton.nix users/seu-usuario.nix

# Editar o arquivo (substituir "skeleton" pelo nome real do usuário)
nano users/seu-usuario.nix
```

Para **criar um segundo usuário sem sudo**, copie o skeleton novamente e remova a linha `"wheel"` do `extraGroups`:

```bash
cp users/skeleton.nix users/outro-usuario.nix
nano users/outro-usuario.nix
# Remova a linha: "wheel" # sudo
```

Descomente (ou adicione) as linhas de importação dos usuários em `hosts/$HOST/configuration.nix`:
```nix
./../../users/seu-usuario.nix
./../../users/outro-usuario.nix
```

> ⚠️ **IMPORTANTE — adicionar o arquivo ao índice do git**
>
> O Nix avalia flakes a partir do **índice do git**, não do sistema de arquivos
> diretamente. Arquivos não rastreados que não estejam no índice são
> **invisíveis ao Nix** e não chegam ao `/nix/store`, causando erros do tipo
> _"module not found"_ no `nixos-install`.
>
> Execute o comando abaixo para incluir o arquivo no índice:
>
> ```bash
> git add users/seu-usuario.nix
> ```

### 8. Instalar o NixOS

> **Apenas para `barbudus` (usa Lanzaboote):** crie as chaves Secure Boot *antes* do `nixos-install`. Sem isso, o instalador falha com `Failed to install bootloader`.
>
> ```bash
> sudo mkdir -p /mnt/persist/etc/secureboot
> sudo nix run \
>   --option extra-substituters "https://nix-community.cachix.org" \
>   --option extra-trusted-public-keys "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCUSeBs=" \
>   nixpkgs#sbctl -- --disable-landlock create-keys \
>   --export /mnt/persist/etc/secureboot/keys \
>   --database-path /mnt/persist/etc/secureboot/GUID
> ```
>
> > **Por quê `--disable-landlock`?** O sbctl ativa o sandbox Landlock (LSM do Linux) antes
> > de processar as flags de caminho. O Landlock é configurado com o caminho padrão
> > `/var/lib/sbctl`, bloqueando qualquer acesso a `/mnt/persist/etc/secureboot` — mesmo
> > para root. Isso causa o erro `sbctl requires root to run: open ... permission denied`.
> >
> > **Por quê dois flags de caminho?** `--database-path` define apenas o arquivo GUID;
> > `--export` define o diretório de chaves. Juntos criam a estrutura completa esperada
> > pelo Lanzaboote em `pkiBundle = "/persist/etc/secureboot"`:
> > `GUID`, `keys/PK/`, `keys/KEK/`, `keys/db/`.

```bash
# Copiar a configuração para /mnt
sudo cp -r /tmp/nixos-config /mnt/etc/nixos

# Instalar o sistema
# Os flags --option passam o cache nix-community explicitamente, tornando a
# instalação resiliente a falhas de download do crates.io (ex: lanzaboote/Rust).
# --option accept-flake-config true aplica a nixConfig do flake (substituter + chave)
# simultaneamente, evitando avisos de substitutos sem chave confiável.
sudo nixos-install \
  --flake /mnt/etc/nixos#$HOST \
  --option accept-flake-config true \
  --option extra-substituters "https://nix-community.cachix.org" \
  --option extra-trusted-public-keys "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCUSeBs="
```

Durante a instalação será solicitado:
- Senha para o usuário root (após a instalação)

### 9. Configurar senhas

Os usuários criados com `initialPassword = "nixos"` (padrão do skeleton) **serão solicitados a criar sua própria senha no primeiro login**. Não é necessário definir senhas manualmente.

Se preferir definir senhas personalizadas durante a instalação, copie o shadow para `/persist` para que sobreviva ao próximo boot (a raiz tmpfs é reiniciada a cada boot; `/persist` é preservado via Btrfs):

```bash
# Entrar no sistema recém-instalado
sudo nixos-enter --root /mnt

# Definir senha para cada usuário criado
passwd seu-usuario
passwd outro-usuario  # se houver mais de um

# Definir senha para o root (opcional, mas recomendado)
passwd root

exit

# IMPORTANTE: copiar shadow para /persist (persiste entre boots via impermanência)
sudo mkdir -p /mnt/persist/etc
sudo cp -p /mnt/etc/shadow /mnt/persist/etc/shadow

# Criar arquivos de flag para evitar a troca forçada no primeiro login
# (apenas para usuários que já definiram sua senha acima)
sudo touch /mnt/persist/.password-change-required-<seu-usuario>
```

> **Nota:** Se as senhas forem definidas via `nixos-enter` sem copiar o shadow para `/persist`, elas serão perdidas após o primeiro reboot — a raiz tmpfs é sempre reiniciada com estado vazio. Os usuários receberão a senha temporária `nixos` e serão solicitados a trocá-la.

### 10. Finalizar instalação

```bash
# Desmontar e reiniciar
sudo umount -R /mnt
sudo reboot
```

## 🔐 Primeiro Boot

1. **Desbloqueio LUKS**: Digite a senha de criptografia definida durante o disko
2. **Login**: Use o usuário criado com a senha definida durante a instalação.
   Se nenhuma senha foi definida, use a senha temporária **`nixos`** — o sistema solicitará que você a troque imediatamente.
3. **Flatpaks** (instalação automática):
   Os Flatpaks da lista pré-definida (GNOME apps, Flatseal, MissionCenter, etc.) são instalados
   automaticamente pelo serviço `install-system-flatpaks` na primeira vez que o sistema iniciar
   com acesso à internet. Nenhuma ação manual é necessária.

   Para acompanhar o status:
   ```bash
   systemctl status install-system-flatpaks
   journalctl -u install-system-flatpaks -f
   ```

   > **Nota:** O repositório Flathub é pré-configurado pelo `install.sh` durante a instalação.
   > Se o serviço falhar (sem internet no primeiro boot), ele tentará novamente automaticamente.

## 🥾 Menu de Boot (systemd-boot)

O menu do systemd-boot está **oculto por padrão** (`timeout = 0`) para proporcionar um boot
mais rápido e sem flickering.

### Como exibir o menu de boot

- **Durante o boot**: mantenha pressionada a tecla **Space** (ou qualquer tecla) imediatamente
  após a tela do firmware UEFI aparecer. O menu do systemd-boot será exibido.

- **Temporariamente via terminal** (define um timeout até o próximo rebuild):
  ```bash
  sudo bootctl set-timeout 5
  ```

- **Para reverter ao comportamento silencioso**:
  ```bash
  sudo bootctl set-timeout 0
  ```

## 🔒 Configuração do Secure Boot (apenas barbudus)

As chaves PKI do Lanzaboote são criadas automaticamente durante a instalação (passo 9 do script ou manualmente antes do `nixos-install`). O que resta fazer após o primeiro boot é **registrar as chaves no firmware UEFI**.

> ### ⚠️ Lanzaboote vs. MOK/shim — diferença importante
>
> Esta configuração usa **lanzaboote**, que **NÃO** utiliza shim nem MOK.
> - **Não haverá** tela azul do MOKmanager durante o boot
> - **Não será solicitada** nenhuma senha de MOK
> - O lanzaboote assina os binários EFI (kernel + initrd) diretamente com chaves PKI
>   próprias (PK/KEK/db) que são registradas no firmware UEFI
> - As chaves ficam em `/persist/etc/secureboot` (configurado via `pkiBundle` no lanzaboote)
>
> A ausência de uma tela de MOK é **esperada e correta** nesta configuração.

> ### ⚠️ Pré-requisito: Setup Mode ativo
>
> Para registrar as chaves PKI, o firmware precisa estar em **Setup Mode** (sem chaves de
> Secure Boot cadastradas). Se o Setup Mode não estiver ativo, o registro falhará.
>
> **Como verificar/habilitar o Setup Mode:**
> 1. Reinicie e acesse a BIOS/UEFI (F2, F12, Del ou Esc durante o boot)
> 2. Na seção Secure Boot, procure **"Delete All Secure Boot Keys"**, **"Setup Mode"**,
>    **"Clear Secure Boot Keys"** ou opção similar
> 3. Apague as chaves existentes (isso habilita o Setup Mode)
> 4. Salve e reinicie para o NixOS com Secure Boot **desabilitado**
>
> O script `setup-secureboot.sh` verifica automaticamente o Setup Mode e aborta com
> instruções claras se o firmware não estiver em Setup Mode.

### Passo a passo para configurar o Secure Boot

```bash
# 1. Entrar no sistema normalmente (Secure Boot desabilitado na BIOS, Setup Mode ativo)

# 2. Verificar o estado atual das chaves e do Setup Mode
sudo sbctl status

# 3. Executar o script de configuração (verifica Setup Mode, registra chaves e assina binários)
sudo bash /etc/nixos/scripts/setup-secureboot.sh

# 4. Rebuildar para garantir que os binários mais recentes estão assinados
sudo nixos-rebuild switch --flake /etc/nixos#barbudus

# 5. Habilitar Secure Boot na BIOS/UEFI e reiniciar

# 6. Verificar se tudo está correto após o reboot
sudo sbctl status
sudo bash /etc/nixos/scripts/setup-secureboot.sh --verify-only
```

> **Nota:** Se as chaves não existirem em `/persist/etc/secureboot` (instalação manual sem o passo de sbctl), crie-as com `sudo sbctl create-keys` antes de prosseguir.

## 🔑 Desbloqueio Automático LUKS via TPM2

Esta configuração inclui suporte ao desbloqueio automático do volume LUKS utilizando o chip TPM2 do hardware. Quando configurado, o sistema desbloqueia o disco automaticamente durante o boot, sem solicitar senha — desde que as medições de integridade do sistema não tenham sido alteradas.

### Como Funciona

O TPM2 armazena a chave LUKS protegida por **PCRs (Platform Configuration Registers)** — medições do estado do firmware e do boot loader. Se o hardware ou software for adulterado, os PCRs mudam e o TPM2 recusa liberar a chave, exigindo a senha de recuperação.

**PCRs configurados:**
| PCR | O que mede |
|-----|-----------|
| 0   | Firmware UEFI (integridade da BIOS) |
| 2   | Código de opção UEFI (drivers ROM) |
| 7   | Estado do Secure Boot |

### Registrar o TPM2 no Volume LUKS

Execute após o primeiro boot com o sistema instalado:

```bash
# Verificar se o TPM2 está disponível
ls /dev/tpm* && tpm2_getcap properties-fixed 2>/dev/null | head -5

# Identificar a partição LUKS
# (normalmente a segunda partição do disco de instalação)
lsblk -f | grep crypto_LUKS

# Registrar o TPM2 (substitua /dev/nvme0n1p2 pela sua partição LUKS)
sudo systemd-cryptenroll \
  --tpm2-device=auto \
  --tpm2-pcrs=0+2+7 \
  /dev/disk/by-partlabel/luks

# Ou usando o device diretamente:
# sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+2+7 /dev/nvme0n1p2
```

Durante o registro, será solicitada a senha atual do LUKS para autorizar a adição do TPM2.

### Testar o Desbloqueio

```bash
# Verificar os slots LUKS configurados
sudo cryptsetup luksDump /dev/disk/by-partlabel/luks | grep -A5 "Tokens\|Keyslots"

# Reiniciar para testar o desbloqueio automático
sudo reboot
```

### Remoção do TPM2 (Revogação)

Para revogar o acesso TPM2 (ex: antes de vender ou reparar o hardware):

```bash
# Remover o token TPM2 e seu keyslot associado
sudo systemd-cryptenroll --wipe-slot=tpm2 /dev/disk/by-partlabel/luks
```

### Fallback para Senha Manual

Se o TPM2 falhar (boot em hardware diferente, atualização de firmware, mudança no Secure Boot), o sistema solicitará a senha LUKS automaticamente como fallback. **Sempre mantenha a senha de recuperação em local seguro.**

## 🔍 Sensor de Impressão Digital (barbudus)

Para usar o sensor de impressão digital Goodix no barbudus:

```bash
# 1. Atualizar os hashes nos derivativos em hosts/barbudus/configuration.nix
# Obter hash do libfprint fork:
nix-prefetch-github infinytum libfprint --rev unstable

# Obter hash do goodix-fp-dump:
nix-prefetch-github goodix-fp-linux-dev goodix-fp-dump --rev master

# 2. Atualizar os sha256 em hosts/barbudus/configuration.nix

# 3. Rebuildar o sistema
sudo nixos-rebuild switch --flake /etc/nixos#barbudus

# 4. Registrar impressão digital
fprintd-enroll

# 5. Testar
fprintd-verify
```

## 📝 Pós-instalação

### Atualizar o sistema

```bash
# Atualizar flake.lock (todos os inputs)
cd /etc/nixos
sudo nix flake update

# Rebuildar sistema
sudo nixos-rebuild switch --flake /etc/nixos#barbudus  # ou bigodon
```

### Verificar o sistema

```bash
# Ver subvolumes Btrfs e uso de disco
sudo btrfs subvolume list /nix
sudo btrfs filesystem usage /nix

# Ver uso da raiz tmpfs
df -h /

# Ver swap ativo
swapon --show
zramctl

# Ver status do Flatpak
flatpak list --system

# Ver containers Podman
podman system info
```

### Snapshots Btrfs manuais

```bash
# Snapshot do subvolume home
sudo btrfs subvolume snapshot /home /.snapshots/home-$(date +%Y%m%d-%H%M%S)

# Snapshot do persist (dados críticos)
sudo btrfs subvolume snapshot /persist /.snapshots/persist-$(date +%Y%m%d-%H%M%S)

# Snapshot do nix (opcional, grande)
sudo btrfs subvolume snapshot /nix /.snapshots/nix-$(date +%Y%m%d-%H%M%S)

# Listar snapshots
sudo btrfs subvolume list /.snapshots

# Remover snapshot antigo
sudo btrfs subvolume delete /.snapshots/home-20240101-120000
```

> **Nota:** Não é necessário fazer snapshot de `/` — a raiz é um tmpfs que é sempre
> reiniciada limpa a cada boot. Apenas `/home`, `/persist` e `/nix` precisam de backup.

## 🔧 Solução de Problemas

### Sistema não boota após primeiro setup

Se o sistema não boota na primeira vez após o disko:

```bash
# Boot no USB live
# Abrir LUKS
sudo cryptsetup open /dev/nvme0n1p2 crypted

# Ativar LVM
sudo vgchange -ay

# Montar subvolumes Btrfs manualmente
sudo mount /dev/nvme0n1p1 /mnt/boot
sudo mount -t btrfs -o subvol=@nix /dev/root_vg/root /mnt/nix
sudo mount -t btrfs -o subvol=@persist /dev/root_vg/root /mnt/persist
sudo mount -t btrfs -o subvol=@home /dev/root_vg/root /mnt/home

# Entrar no sistema
sudo nixos-enter --root /mnt
```

### Verificar Btrfs

```bash
# Status do filesystem
sudo btrfs filesystem show /
sudo btrfs device stats /

# Verificar integridade (scrub)
sudo btrfs scrub start /
sudo btrfs scrub status /

# Estatísticas de compressão
sudo compsize /
sudo compsize /home
```

### Problemas com LUKS

```bash
# Listar containers LUKS
sudo cryptsetup status crypted

# Verificar cabeçalho LUKS
sudo cryptsetup luksDump /dev/nvme0n1p2
```

## 📚 Referências

- [Manual do NixOS](https://nixos.org/manual/nixos/stable/)
- [Disko](https://github.com/nix-community/disko)
- [Impermanence](https://github.com/nix-community/impermanence)
- [Home Manager](https://github.com/nix-community/home-manager)
- [Lanzaboote (Secure Boot)](https://github.com/nix-community/lanzaboote)
- [Btrfs on NixOS](https://nixos.wiki/wiki/Btrfs)
- [Arch Wiki — Btrfs](https://wiki.archlinux.org/title/Btrfs)
- [Erase Your Darlings](https://grahamc.com/blog/erase-your-darlings/)
