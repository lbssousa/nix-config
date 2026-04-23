# Camada Privada (`./private`)

Este repositório suporta uma **camada privada opcional** para configurações pessoais
que não devem ser versionadas publicamente: definição de usuários, preferências via
home-manager, segredos (Wi-Fi, tokens, chaves SSH), etc.

A camada é carregada **apenas se o diretório `./private` estiver presente** na raiz
do checkout público. Sem ele, o flake continua 100% avaliável e buildável.

---

## Como funciona

O `flake.nix` público verifica a existência de `./private/modules.nix` via
`builtins.pathExists`. Se encontrado, importa a lista de módulos NixOS retornada
por ele e os adiciona a todos os `nixosConfigurations`. Se não encontrado, usa uma
lista vazia — sem erros, sem módulos extras.

```nix
# Trecho de flake.nix (simplificado)
privateModules =
  if builtins.pathExists ./private/modules.nix then import ./private/modules.nix else [ ];
```

Como o Nix avalia flakes a partir do índice git (não do commit), arquivos
gitignored podem ser tornados visíveis com `git add --force` **sem precisar
fazer commit**.

---

## Configuração inicial

### 1. Criar o repositório privado (uma vez)

```bash
# No GitHub (ou outro host git), crie um repo privado:
# https://github.com/new  →  nome: nixos-config-private  →  Private

# Clone-o dentro do checkout público:
cd /caminho/para/nixos-config
git clone git@github.com:lbssousa/nixos-config-private private
```

Se preferir começar sem um repositório remoto, crie a estrutura manualmente:

```bash
mkdir -p private/nixos private/home
```

### 2. Copiar os templates de exemplo

```bash
cp docs/private-example/modules.nix          private/modules.nix
cp docs/private-example/nixos/users.nix      private/nixos/users.nix
cp docs/private-example/home/meuusuario.nix  private/home/meuusuario.nix
# Edite os arquivos copiados conforme sua necessidade
```

### 3. Tornar os arquivos visíveis ao Nix

O diretório `private/` está no `.gitignore` do repo público para nunca ser
commitado acidentalmente. Para que o Nix inclua esses arquivos na avaliação do
flake, force-os para o índice git (sem fazer commit):

```bash
git add --force private/
```

> **Repita este comando** após cada atualização do repo privado (ex.: `git pull`
> dentro de `private/`), ou configure um git hook para automatizar:
>
> ```bash
> # .git/hooks/post-merge (torne executável com chmod +x)
> #!/usr/bin/env bash
> git add --force private/ 2>/dev/null || true
> ```

### 4. Rebuildar o sistema

```bash
sudo nixos-rebuild switch --flake .#barbudus
# ou
sudo nixos-rebuild switch --flake .#bigodon
```

---

## Estrutura esperada do repo privado

```
private/
├── flake.nix              # Opcional — para versionamento do próprio privado
├── modules.nix            # OBRIGATÓRIO — lista de módulos NixOS a importar
├── nixos/
│   ├── users.nix          # Definição de usuários + home-manager.users.*
│   ├── wifi.nix           # Redes Wi-Fi pessoais (opcional)
│   └── secrets.nix        # Integração com sops-nix (opcional)
└── home/
    └── meuusuario.nix     # Configuração home-manager personalizada
```

Veja `docs/private-example/` para templates comentados de cada arquivo.

### `modules.nix` — ponto de entrada

Deve retornar uma **lista de módulos NixOS** (caminhos ou attrsets):

```nix
# private/modules.nix
[
  ./nixos/users.nix
  # ./nixos/wifi.nix
  # ./nixos/secrets.nix
]
```

### `nixos/users.nix` — usuários e home-manager

Define `users.users.*`, `environment.persistence.*` e `home-manager.users.*`.
Como o home-manager já está carregado pelo flake público como módulo NixOS,
você pode configurar `home-manager.users.*` diretamente aqui.

```nix
# private/nixos/users.nix
{ pkgs, ... }: {
  users.users.luiz = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAA..." ];
    initialPassword = "nixos";
  };

  environment.persistence."/persist".users.luiz = {
    directories = [ "Downloads" "Documents" ".ssh" ".gnupg" ];
    files = [ ".zsh_history" ];
  };

  home-manager.users.luiz = {
    imports = [ ../home/luiz.nix ];
  };
}
```

---

## Sem a camada privada

Quem clonar apenas `lbssousa/nixos-config` (sem `./private`) pode:

```bash
nixos-rebuild build --flake .#barbudus
```

O build funciona normalmente — sem usuários pessoais, sem configurações de
home-manager privadas e sem segredos. Ideal para CI, testes e contribuições.

---

## Segredos (avançado)

Para segredos (tokens, senhas, chaves privadas SSH), recomenda-se usar
[sops-nix](https://github.com/Mic92/sops-nix) com chaves `age`. O módulo de
segredos fica em `private/nixos/secrets.nix` e é carregado pelo `modules.nix`
do privado. Dessa forma, o repo público **nunca** depende de sops-nix —
a dependência fica inteiramente na camada privada.

Recursos para começar:
- [sops-nix README](https://github.com/Mic92/sops-nix)
- [age key generation](https://age-encryption.org/)

### Restaurar a chave age durante a instalação

Se você usa sops-nix com secrets necessários **logo após o primeiro boot**
(por exemplo, senhas de Wi-Fi declaradas em `private/nixos/wifi.nix`), a chave
age precisa estar presente em `$HOME/.config/sops/age/keys.txt` antes que o
sistema seja iniciado.

O diretório `/home` é um subvolume Btrfs persistente (`@home`), portanto o
arquivo sobrevive entre boots — mas precisa ser colocado lá **durante a
instalação**, enquanto os filesystems estão montados em `/mnt`.

Após particionar e montar os filesystems (e antes de executar `nixos-install`),
restaure o backup da chave para cada usuário que precisa dela:

```bash
# Substitua <usuario> pelo nome do usuário correspondente
install -d -m 700 /mnt/home/<usuario>/.config/sops/age
install -m 600 /caminho/para/backup/keys.txt \
  /mnt/home/<usuario>/.config/sops/age/keys.txt
```

> **Nota:** O `install -d -m 700` cria o diretório com permissões corretas.
> O `install -m 600` copia o arquivo garantindo que apenas o dono possa lê-lo,
> o que é exigido pelo sops-nix.

Se o backup estiver em mídia removível (pen drive, disco externo), monte-a
primeiro:

```bash
mkdir -p /mnt/backup
mount /dev/sdX1 /mnt/backup   # Ajuste o dispositivo conforme necessário

install -d -m 700 /mnt/home/<usuario>/.config/sops/age
install -m 600 /mnt/backup/keys.txt \
  /mnt/home/<usuario>/.config/sops/age/keys.txt
```

---

## Resumo do workflow diário

```bash
# Atualizar o repo privado
cd /etc/nixos/private && git pull && cd ..

# Re-indexar os arquivos privados para o Nix
git add --force private/

# Rebuildar
sudo nixos-rebuild switch --flake .#barbudus
```
