# Guia de Instalação do NixOS

Este guia cobre a instalação do NixOS usando esta configuração baseada em Flakes com ZFS, disko, impermanence e swap híbrida.

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

# 3. Executar o script (modo interativo — recomendado para a maioria dos casos)
bash scripts/install.sh
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
bash scripts/install.sh --help
```

#### Exemplos

**Instalação totalmente interativa** (recomendado para iniciantes):

```bash
bash scripts/install.sh
```

**Instalação não-interativa** (útil para automação ou reinstalações):

```bash
bash scripts/install.sh \
  --host barbudus \
  --disk /dev/nvme0n1 \
  --user "joao:cavalo:sudo" \
  --user "maria:macaco:nosudo" \
  --non-interactive
```

**Pré-selecionar host e disco, mas confirmar usuários interativamente:**

```bash
bash scripts/install.sh --host bigodon --disk /dev/sda
```

#### O que o script faz

1. Habilita Flakes no ambiente live (usuário atual e root)
2. Lista hosts e discos disponíveis para seleção
3. Atualiza o `disko.nix` do host com o disco escolhido
4. Particiona e formata o disco com disko (⚠️ apaga todos os dados!)
5. Gera o `hostId` ZFS e atualiza `hardware-configuration.nix`
6. Cria arquivos de usuário a partir do skeleton
7. Adiciona os arquivos de usuário ao índice do git (`git add --force`)
8. Atualiza `configuration.nix` com os imports dos usuários
9. Copia a configuração para `/mnt/etc/nixos` e executa `nixos-install`
10. Define senhas via `nixos-enter`

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

# Habilitar Flakes temporariamente
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
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
sudo nix run github:nix-community/disko -- --mode disko ./hosts/$HOST/disko.nix
```

Este comando irá:
1. Criar partições GPT (EFI 512MB + partição LUKS)
2. Configurar criptografia LUKS (será solicitada senha durante o processo)
3. Criar volumes LVM (swap 20GB + volume ZFS)
4. Criar pool ZFS `rpool` com os datasets:
   - `rpool/local/root` → `/` (efêmero)
   - `rpool/local/nix` → `/nix`
   - `rpool/local/log` → `/var/log`
   - `rpool/local/containers` → `/var/lib/containers`
   - `rpool/safe/home` → `/home`
   - `rpool/safe/persist` → `/persist`
   - `rpool/safe/flatpak` → `/var/lib/flatpak`
5. Montar tudo em `/mnt`

### 6. Configurar o hostId ZFS

O ZFS requer um `hostId` único. Gere e ajuste:

```bash
# Gerar um hostId único (8 caracteres hexadecimais)
head -c 8 /dev/urandom | od -A n -t x1 | tr -d ' \n'
# Exemplo de saída: a8b3c4d5

# Editar hardware-configuration.nix do host
nano hosts/$HOST/hardware-configuration.nix
# Substitua o valor de networking.hostId pelo valor gerado acima
```

### 7. Gerar configuração de hardware (recomendado)

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
2. Adicionar `networking.hostId` com o valor gerado no passo anterior
3. Adicionar as configurações de `zramSwap`
4. Manter `fileSystems."/persist".neededForBoot = true`

### 8. Criar arquivos de usuário

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
> diretamente. Arquivos git-ignorados que não estejam no índice são
> **invisíveis ao Nix** e não chegam ao `/nix/store`, causando erros do tipo
> _"module not found"_ no `nixos-install`.
>
> Execute o comando abaixo para incluir o arquivo no índice **sem** fazer commit:
>
> ```bash
> git add --force users/seu-usuario.nix
> ```
>
> Isso torna o arquivo visível ao Nix sem expô-lo no histórico do repositório.

### 9. Instalar o NixOS

```bash
# Copiar a configuração para /mnt
sudo cp -r /tmp/nixos-config /mnt/etc/nixos

# Instalar o sistema
sudo nixos-install --flake /mnt/etc/nixos#$HOST
```

Durante a instalação será solicitado:
- Senha para o usuário root (após a instalação)

### 10. Configurar senhas

```bash
# Entrar no sistema recém-instalado
sudo nixos-enter --root /mnt

# Definir senha para cada usuário criado
passwd seu-usuario
passwd outro-usuario  # se houver mais de um

# Definir senha para o root (opcional, mas recomendado)
passwd root

exit
```

### 11. Finalizar instalação

```bash
# Desmontar e reiniciar
sudo umount -R /mnt
sudo reboot
```

## 🔐 Primeiro Boot

1. **Desbloqueio LUKS**: Digite a senha de criptografia definida durante o disko
2. **Login**: Use o usuário criado e a senha definida com `passwd`
3. **Configurar Flatpaks**:
   ```bash
   flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
   flatpak install flathub org.gnome.Papers
   flatpak install flathub app.devsuite.Ptyxis
   flatpak install flathub io.github.bazaar_cabinet.Bazaar
   ```

4. **Instalar Homebrew** (opcional):
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

## 🔒 Configuração do Secure Boot (apenas barbudus)

Para habilitar o Secure Boot com NVIDIA no barbudus, siga estes passos **antes** de habilitar o Secure Boot na BIOS:

```bash
# 1. Entrar no sistema normalmente (Secure Boot desabilitado)

# 2. Inicializar o bundle PKI do lanzaboote
sudo sbctl create-keys

# 3. Verificar o status
sudo sbctl verify

# 4. Assinar os binários do boot
sudo sbctl sign-all

# 5. Verificar a assinatura
sudo sbctl verify

# 6. Habilitar Secure Boot na BIOS/UEFI
# Entre na BIOS, habilite o Secure Boot e adicione suas chaves

# 7. Rebuildar o sistema
sudo nixos-rebuild switch --flake /etc/nixos#barbudus
```

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
# Ver datasets ZFS e uso de disco
zfs list

# Ver swap ativo
swapon --show
zramctl

# Ver status do Flatpak
flatpak list --system

# Ver containers Podman
podman system info
```

## 🔧 Solução de Problemas

### Sistema não boota após primeiro setup

Se o sistema não boota na primeira vez após o disko:

```bash
# Boot no USB live
# Abrir LUKS
sudo cryptsetup open /dev/nvme0n1p2 crypted

# Ativar LVM
sudo vgchange -ay

# Importar pool ZFS
sudo zpool import -f rpool

# Montar datasets
sudo mount -t zfs rpool/local/root /mnt
sudo mount /dev/nvme0n1p1 /mnt/boot
sudo mount -t zfs rpool/local/nix /mnt/nix
sudo mount -t zfs rpool/safe/persist /mnt/persist

# Entrar no sistema
sudo nixos-enter --root /mnt
```

### Problemas com o rollback ZFS

Se o sistema esquece configurações entre boots (impermanence funcionando):

```bash
# Verificar snapshots existentes
zfs list -t snapshot

# Ver o snapshot blank (deve existir após instalação)
zfs list -t snapshot rpool/local/root

# Criar o snapshot blank manualmente se não existir
sudo zfs snapshot rpool/local/root@blank
```

### Verificar ZFS pool

```bash
# Status do pool
sudo zpool status

# Verificar integridade
sudo zpool scrub rpool
```

### Erro de hostId ZFS

```bash
# Verificar hostId configurado
cat /etc/machine-id  # Apenas referência

# Ver hostId atual
hostid

# O hostId deve ser fixo e definido em hardware-configuration.nix
# networking.hostId = "xxxxxxxx";
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
- [ZFS on NixOS](https://nixos.wiki/wiki/ZFS)
- [Erase Your Darlings](https://grahamc.com/blog/erase-your-darlings/)
