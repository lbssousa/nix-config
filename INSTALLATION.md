# Guia de Instalação do NixOS

Este guia cobre a instalação do NixOS usando esta configuração baseada em Flakes com Btrfs, disko, preservation e swap híbrida.

## 📋 Pré-requisitos

1. Baixe a ISO do NixOS: [https://nixos.org/download.html](https://nixos.org/download.html)
2. Crie um USB bootável com a ISO
3. Boot no USB do NixOS
4. **YubiKey com chave GPG** (recomendado): necessária para desbloquear o repositório
   `nix-keys` via git-crypt. Sem ela, secrets do sops-nix (ex: senha do Wi-Fi) não
   serão configurados durante a instalação e precisarão ser restaurados manualmente.

## 🚀 Instalação

### Script de Instalação Automatizada (`install.sh`)

O repositório inclui o script `scripts/install.sh` que automatiza todos os passos de instalação descritos neste guia. É a forma mais rápida e segura de instalar o sistema.

#### Como usar

```bash
# 1. Boot no USB do NixOS

# 2. Clonar o repositório de configuração
nix-shell -p git
git clone https://github.com/lbssousa/nix-config.git /tmp/nixos-config
cd /tmp/nixos-config

# 3. (Opcional, mas recomendado) Clonar e desbloquear o nix-keys
#    O nix-keys armazena as chaves age do sops-nix (criptografadas com git-crypt).
#    Sem ele, secrets de sistema (ex: Wi-Fi via sops-nix) não funcionarão após o boot.
nix-shell -p git git-crypt gnupg
git clone git@github.com:lbssousa/nix-keys.git /tmp/nix-keys
cd /tmp/nix-keys && git-crypt unlock  # requer YubiKey inserida
cd /tmp/nixos-config

# 4. Executar o script como root (modo interativo — recomendado para a maioria dos casos)
sudo bash scripts/install.sh
#    O script detectará automaticamente o nix-keys em /tmp/nix-keys e copiará
#    a chave age de sistema para /persist/etc/sops/age/keys.txt.
```

O script irá guiar você por cada etapa, perguntando as informações necessárias.

#### Opções do script

```text
Uso:
  bash scripts/install.sh [--host <hostname>] [--disk <device>]
                          [--partition-profile <btrfs|zfs>]
                          [--user "login:Nome Completo:sudo"]
                          [--user "login2:Nome2:nosudo"] ...
                          [--nix-keys-dir <caminho>]
                          [--age-keys-backup <arquivo>]
                          [--non-interactive]
                          [--help]

Opções:
  --host              Nome do host NixOS (ex: barbudus, bigodon).
                      Se omitido, é perguntado interativamente.
  --disk              Dispositivo de disco de destino (ex: /dev/nvme0n1, /dev/sda).
                      Se omitido, é perguntado interativamente.
  --partition-profile Perfil de particionamento: btrfs (padrão) ou zfs.
                      Se omitido, é perguntado interativamente.
  --user              Usuário no formato "login:Nome Completo:sudo|nosudo".
                      Pode ser repetido para criar múltiplos usuários.
                      "sudo" (padrão) inclui o usuário no grupo wheel (sudo).
                      "nosudo" cria o usuário sem permissão de sudo.
                      Se omitido, é perguntado interativamente.
  --nix-keys-dir      Caminho para o clone local do repositório nix-keys
                      (repositório privado com chaves age do sops-nix, cifrado com
                      git-crypt). Se omitido, procura em ../nix-keys (irmão de nix-config).
  --age-keys-backup   Caminho direto para o arquivo keys.txt da chave age de sistema.
                      Alternativa a --nix-keys-dir quando você tem apenas o arquivo.
  --non-interactive   Não faz perguntas; falha se informações obrigatórias
                      não forem fornecidas via flags.
  --help, -h          Exibe esta ajuda e sai.
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
  --partition-profile btrfs \
  --nix-keys-dir /tmp/nix-keys \
  --user "cavalo:sudo" \
  --user "macaco:nosudo" \
  --non-interactive
```

**Pré-selecionar host e disco, mas confirmar usuários interativamente:**

```bash
sudo bash scripts/install.sh --host bigodon --disk /dev/sda
```

#### O que o script faz

1. Habilita Flakes e o cache nix-community para o root no ambiente live
2. Clona e desbloqueia o repositório `nix-keys` via git-crypt (requer YubiKey ou chave simétrica)
3. Lista hosts e discos disponíveis para seleção
4. Seleciona o perfil de particionamento (Btrfs ou ZFS)
5. Atualiza o `disko.nix` do host com o disco escolhido
6. Particiona e formata o disco com disko (⚠️ apaga todos os dados!)
   - A raiz (`/`) é configurada como tmpfs — limpa automaticamente a cada boot
   - Os dados persistentes ficam em subvolumes Btrfs (ou datasets ZFS) dedicados
7. Cria arquivos de usuário a partir do skeleton
8. Adiciona os arquivos de usuário ao índice do git (`git add`)
9. Atualiza `configuration.nix` com os imports dos usuários
10. Cria chaves Secure Boot em `/persist/etc/secureboot` (apenas hosts com Secure Boot via Limine)
11. Copia a chave age de sistema do `nix-keys` para `/persist/etc/sops/age/keys.txt`
    — permite que o sops-nix descriptografe secrets (Wi-Fi etc.) no primeiro boot
12. Copia a configuração para `/mnt/etc/nixos` e executa `nixos-install`
13. Copia automaticamente as conexões Wi-Fi do live CD para `/persist/etc/NetworkManager/system-connections`
    — o Wi-Fi já estará configurado no primeiro boot, sem precisar redigitar credenciais
14. Define senhas via `passwd --root` e copia `/etc/shadow` para `/persist`

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
# O cache evita compilar dependências do zero e falhas de download.
mkdir -p ~/.config/nix
cat >> ~/.config/nix/nix.conf <<EOF
experimental-features = nix-command flakes
extra-substituters = https://nix-community.cachix.org
extra-trusted-public-keys = nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCUSeBs=
EOF
```

### 2. Clonar os repositórios

```bash
# Instalar git no live environment
nix-shell -p git git-crypt gnupg

# Clonar a configuração do sistema (repositório público)
git clone https://github.com/lbssousa/nix-config.git /tmp/nixos-config
cd /tmp/nixos-config
```

#### 2b. Clonar e desbloquear o nix-keys (repositório de chaves)

O repositório `nix-keys` é um repositório **privado** (SSH) que armazena as chaves age
do `sops-nix`, criptografadas com `git-crypt`. É necessário para que os secrets de sistema
sejam configurados corretamente após a instalação.

Estrutura do `nix-keys`:
- `sops/age/keys.txt` — **chave age de sistema** (descriptografa secrets do NixOS, como a
  senha do Wi-Fi). Copiada para `/persist/etc/sops/age/keys.txt` durante a instalação.
- `sops/age/<usuario>/keys.txt` — **chave age pessoal** de cada usuário (descriptografa
  secrets do Home Manager, como credenciais do rclone). Copiada automaticamente pelo
  script de ativação do Home Manager no **primeiro login** — não é necessária durante a
  instalação.

```bash
# Clonar o nix-keys como irmão do nix-config (detectado automaticamente pelo install.sh)
git clone git@github.com:lbssousa/nix-keys.git /tmp/nix-keys

# Desbloquear com git-crypt (requer YubiKey inserida ou chave simétrica exportada)
cd /tmp/nix-keys
gpg --card-status              # verificar que o YubiKey está reconhecido pelo GPG
git-crypt unlock               # desbloquear via GPG (YubiKey)
# ou: git-crypt unlock /caminho/para/git-crypt.key  # via chave simétrica

cd /tmp/nixos-config
```

> Se o `nix-keys` não estiver disponível durante a instalação, o sistema será instalado
> normalmente mas os secrets do sops-nix (ex: conexões Wi-Fi gerenciadas pelo sops) não
> estarão ativos até que a chave seja restaurada manualmente em
> `/persist/etc/sops/age/keys.txt`.

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

Com arquitetura dendrítica, o vínculo de usuários do sistema é centralizado.
Edite `dendritic/data/users.nix` e adicione os logins na lista `config.dendritic.users`.

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
  "outro-usuario"
];
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

> **Apenas para `barbudus` (Secure Boot via Limine):** crie as chaves Secure Boot _antes_ do `nixos-install`. Sem isso, o instalador falha com `Failed to install bootloader`.
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
> > `--export` define o diretório de chaves. Juntos criam a estrutura completa que o
> > sbctl espera em `/var/lib/sbctl` (symlink para `/persist/etc/secureboot`, criado
> > via `systemd.tmpfiles.rules` no host — o módulo `boot.loader.limine` não tem uma
> > opção de `pkiBundle`, o caminho é sempre fixo):
> > `GUID`, `keys/PK/`, `keys/KEK/`, `keys/db/`.

```bash
# Copiar a configuração para /mnt
sudo cp -r /tmp/nixos-config /mnt/etc/nixos

# Instalar o sistema
# Os flags --option passam o cache nix-community explicitamente, tornando a
# instalação resiliente a falhas de download de dependências.
# --option accept-flake-config true aplica a nixConfig do flake (substituter + chave)
# simultaneamente, evitando avisos de substitutos sem chave confiável.
DESKTOP=plasma  # ou gnome
sudo nixos-install \
  --flake /mnt/etc/nixos#${HOST}-${DESKTOP} \
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

# IMPORTANTE: copiar shadow para /persist (persiste entre boots via preservation)
sudo mkdir -p /mnt/persist/etc
sudo cp -p /mnt/etc/shadow /mnt/persist/etc/shadow

# Criar arquivos de flag para evitar a troca forçada no primeiro login
# (apenas para usuários que já definiram sua senha acima)
sudo touch /mnt/persist/.password-change-required-<seu-usuario>
```

> **Nota:** Se as senhas forem definidas via `nixos-enter` sem copiar o shadow para `/persist`, elas serão perdidas após o primeiro reboot — a raiz tmpfs é sempre reiniciada com estado vazio (a preservation só salva o que está explicitamente declarado). Os usuários receberão a senha temporária `nixos` e serão solicitados a trocá-la.

### 10. Registrar o YubiKey para autenticação U2F

> 💡 **Recomendado para usuários do grupo `wheel`**: quando `/persist/etc/u2f-mappings` existe
> e contém a entrada do usuário, `sudo`, `run0` e `pkexec` exigem toque na YubiKey.
> Se o arquivo não existir ou o usuário não tiver entrada nele, o PAM cai automaticamente
> para autenticação por **senha** — sem lockout.

Com o YubiKey inserido, execute **no ambiente live** (fora do `nixos-enter`):

```bash
# Registrar o primeiro usuário wheel (cria o arquivo):
pamu2fcfg -u seu-usuario > /mnt/persist/etc/u2f-mappings
# Quando o LED do YubiKey piscar, toque-o

# Adicionar cada usuário wheel adicional (acrescenta ao arquivo):
pamu2fcfg -u outro-usuario >> /mnt/persist/etc/u2f-mappings

# Para registrar uma segunda YubiKey de backup para o mesmo usuário,
# use -n (sem prefixo de usuário) e concatene manualmente ao arquivo
# ou repita o processo com a chave de backup no lugar da principal.
```

Verifique o resultado — deve existir uma linha iniciando com o nome de cada usuário `wheel`:

```bash
cat /mnt/persist/etc/u2f-mappings
```

### 11. Finalizar instalação

```bash
# Desmontar e reiniciar
sudo umount -R /mnt
sudo reboot
```

## 🔐 Primeiro Boot

1. **Desbloqueio LUKS**: Digite a senha de criptografia definida durante o disko
2. **Login**: Use o usuário criado com a senha definida durante a instalação.
   Se nenhuma senha foi definida, use a senha temporária **`nixos`** — o sistema solicitará que você a troque imediatamente.
3. **YubiKey U2F** — verificação recomendada antes de tentar `sudo` ou `run0`:

   ```bash
   cat /persist/etc/u2f-mappings
   ```

   O arquivo deve ter uma linha iniciando com o nome de cada usuário do grupo `wheel`.
   Se o arquivo não existir (passo 10 foi pulado), `sudo`, `run0` e `pkexec` ainda
   funcionam via senha — o PAM cai automaticamente para autenticação por senha quando
   não há mapeamento U2F válido.

4. **Secrets do sops-nix** (Wi-Fi e outros): se a chave age de sistema foi copiada
   durante a instalação (passo 6b), os secrets serão ativados automaticamente. Verifique:

   ```bash
   ls /persist/etc/sops/age/keys.txt  # deve existir
   systemctl status sops-nix          # deve mostrar "active"
   ```

   Se o arquivo não existir, clone e desbloqueie o nix-keys primeiro, depois copie a chave:
   ```bash
   # Clonar e desbloquear o nix-keys (necessário apenas se não foi feito durante a instalação)
   NIX_KEYS="$(xdg-user-dir PROJECTS)/lbssousa/nix-keys"
   git clone git@github.com:lbssousa/nix-keys.git "$NIX_KEYS"
   cd "$NIX_KEYS" && git-crypt unlock  # requer YubiKey inserida

   # Copiar a chave age de sistema para /persist
   run0 install -Dm600 "$NIX_KEYS/sops/age/keys.txt" /persist/etc/sops/age/keys.txt

   # Reagenerar os secrets com a chave disponível
   cd /etc/nixos && just nixos switch
   ```

5. **Flatpaks** (instalação automática):

   Os Flatpaks declarados na configuração são instalados automaticamente pelo serviço
   `flatpak-managed-install` na primeira vez que o sistema iniciar com acesso à internet.
   Nenhuma ação manual é necessária.


## 🥾 Menu de Boot (systemd-boot)

O menu do systemd-boot está **oculto por padrão** (`timeout = 0`) para proporcionar um boot
mais rápido e sem flickering.

### Como exibir o menu de boot

- **Durante o boot**: mantenha pressionada a tecla **Space** (ou qualquer tecla) imediatamente
  após a tela do firmware UEFI aparecer. O menu do systemd-boot será exibido.

- **Temporariamente via terminal** (define um timeout até o próximo rebuild): `sudo bootctl set-timeout 5`

- **Para reverter ao comportamento silencioso**: `sudo bootctl set-timeout 0`

## 🔒 Configuração do Secure Boot (apenas barbudus)

As chaves PKI são criadas automaticamente durante a instalação (passo 9 do script ou manualmente antes do `nixos-install`). O que resta fazer após o primeiro boot é **registrar as chaves no firmware UEFI**.

### ⚠️ Limine vs. MOK/shim — diferença importante

Esta configuração usa **Limine** (`boot.loader.limine.secureBoot`), que **NÃO** utiliza shim nem MOK.

- **Não haverá** tela azul do MOKmanager durante o boot
- **Não será solicitada** nenhuma senha de MOK
- O firmware verifica apenas a assinatura PE do binário do Limine, feita com chaves
  PKI próprias (PK/KEK/db) registradas no firmware UEFI
- A integridade do kernel/initrd é garantida por checksum BLAKE2B embutido no
  `limine.conf` (cujo hash, por sua vez, está embutido no binário assinado do
  Limine via `enroll-config`) — não por assinatura individual de cada arquivo
- As chaves ficam em `/persist/etc/secureboot`, symlinkado para `/var/lib/sbctl`
  (caminho fixo esperado pelo sbctl; o módulo `boot.loader.limine` não tem uma
  opção equivalente ao `pkiBundle` do lanzaboote)

A ausência de uma tela de MOK é **esperada e correta** nesta configuração.

### ⚠️ Pré-requisito: Setup Mode ativo

Para registrar as chaves PKI, o firmware precisa estar em **Setup Mode** (sem chaves de
Secure Boot cadastradas). Se o Setup Mode não estiver ativo, o registro falhará.

**Como verificar/habilitar o Setup Mode:**

1. Reinicie e acesse a BIOS/UEFI (F2, F12, Del ou Esc durante o boot)
2. Na seção Secure Boot, procure **"Delete All Secure Boot Keys"**, **"Setup Mode"**,
   **"Clear Secure Boot Keys"** ou opção similar
3. Apague as chaves existentes (isso habilita o Setup Mode)
4. Salve e reinicie para o NixOS com Secure Boot **desabilitado**

O script `setup-secureboot.sh` verifica automaticamente o Setup Mode e aborta com
instruções claras se o firmware não estiver em Setup Mode.

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

| PCR | O que mede                            |
| --- | ------------------------------------- |
| 0   | Firmware UEFI (integridade da BIOS)   |
| 2   | Código de opção UEFI (drivers ROM)    |
| 7   | Estado do Secure Boot                 |

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

O barbudus usa o sensor Goodix 538d (USB `27c6:538d`), suportado pelo fork
`lbssousa/libfprint` (branch `goodix-538d-sigfm-gtls`, baseado no libfprint 1.94.10).
Os pacotes `libfprint-goodix` e `fprintd-goodix` já estão declarados em
`pkgs/libfprint-goodix/` e `pkgs/fprintd-goodix/` e habilitados em
`hosts/barbudus/configuration.nix` — nenhuma configuração manual é necessária após
a instalação.

Para registrar e testar a impressão digital:

```bash
# Registrar impressão digital (executa fprintd-enroll para o usuário atual)
fprintd-enroll

# Verificar o registro
fprintd-verify

# Listar dispositivos reconhecidos pelo fprintd
fprintd-list "$USER"
```

## 📝 Pós-instalação

### Configurar nix-keys para o Home Manager

O script de ativação do Home Manager do usuário `abutre` copia automaticamente a chave
age pessoal de `$(xdg-user-dir PROJECTS)/lbssousa/nix-keys/sops/age/abutre/keys.txt`
para `~/.config/sops/age/keys.txt`. Para que isso funcione no primeiro `just switch`,
o repositório `nix-keys` precisa estar clonado e desbloqueado no diretório de projetos:

```bash
# Clonar o nix-keys no diretório de projetos do usuário
NIX_KEYS_DIR="$(xdg-user-dir PROJECTS)/lbssousa/nix-keys"
git clone git@github.com:lbssousa/nix-keys.git "$NIX_KEYS_DIR"

# Desbloquear via GPG (YubiKey)
gpg --card-status               # verificar que o YubiKey está reconhecido
cd "$NIX_KEYS_DIR"
git-crypt unlock

# Aplicar NixOS + Home Manager — o script de ativação copiará a chave age pessoal automaticamente
cd /etc/nixos
just switch
```

Se a chave age pessoal não estiver disponível no momento do `just switch`, o
script de ativação emitirá um aviso indicando que deve clonar e desbloquear o nix-keys.
Secrets do Home Manager (como credenciais do rclone) não funcionarão até que a chave
seja restaurada.

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

### Registrar YubiKey após o primeiro boot

Se o passo 10 foi pulado durante a instalação, `sudo`, `run0` e `pkexec` continuam
funcionando via senha (o PAM cai automaticamente para autenticação por senha quando
não há mapeamento U2F válido). Para ativar a autenticação por YubiKey depois do boot:

**Opção normal — via senha (caminho mais simples)**

Com o sistema rodando e a YubiKey inserida, use a senha para autenticar o `run0`:

```bash
pamu2fcfg -u seu-usuario | run0 tee /persist/etc/u2f-mappings
# Toque o YubiKey quando o LED piscar
pamu2fcfg -u outro-usuario | run0 tee -a /persist/etc/u2f-mappings  # usuários adicionais
```

**Opção A — Modo de emergência**

Necessária apenas se a conta não tiver senha válida. No menu do systemd-boot (segure
**Space** durante o boot), pressione **e** na entrada desejada e acrescente ao final
da linha `options`:

```
systemd.unit=emergency.target
```

Isso fornece um shell root sem autenticação. Com o YubiKey inserido:

```bash
pamu2fcfg -u seu-usuario > /persist/etc/u2f-mappings
pamu2fcfg -u outro-usuario >> /persist/etc/u2f-mappings  # se houver mais de um
```

Reinicie normalmente após criar o arquivo.

> **barbudus (Secure Boot/Limine)**: o editor do menu de boot é desabilitado
> quando o Secure Boot está ativo. Use a Opção B.

**Opção B — Live ISO**

Boot pelo pendrive NixOS, monte o subvolume Btrfs `@persist` e crie o arquivo:

```bash
sudo cryptsetup open /dev/nvme0n1p2 crypted
sudo vgchange -ay
sudo mount -t btrfs -o subvol=@persist /dev/root_vg/root /mnt
pamu2fcfg -u seu-usuario | sudo tee /mnt/etc/u2f-mappings
pamu2fcfg -u outro-usuario | sudo tee -a /mnt/etc/u2f-mappings
sudo umount /mnt
```

Após qualquer uma das opções, reinicie normalmente e verifique:

```bash
cat /persist/etc/u2f-mappings  # deve mostrar uma linha por usuário
run0 id                        # deve exibir uid=0(root)
```

## 📚 Referências

- [Manual do NixOS](https://nixos.org/manual/nixos/stable/)
- [Disko](https://github.com/nix-community/disko)
- [Preservation](https://github.com/nix-community/preservation)
- [Home Manager](https://github.com/nix-community/home-manager)
- [Limine Bootloader](https://github.com/limine-bootloader/limine)
- [Btrfs on NixOS](https://nixos.wiki/wiki/Btrfs)
- [Arch Wiki — Btrfs](https://wiki.archlinux.org/title/Btrfs)
- [Erase Your Darlings (sistema efêmero)](https://grahamc.com/blog/erase-your-darlings/)
