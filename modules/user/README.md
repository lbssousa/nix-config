# modules/user

Módulos Home Manager user-wide — utilizados pelo `home-manager switch`.

Cada subpasta agrupa módulos por categoria funcional.

## Categorias

| Pasta | Descrição |
|-------|-----------|
| [apps/](apps/) | Aplicativos instalados para o usuário (Brave Browser, etc.) |
| [dev/](dev/) | Ferramentas de desenvolvimento |
| [shell/](shell/) | Configuração de shell e ambiente do usuário |

## Uso

Importe os módulos desejados no arquivo do usuário ou via `home-manager.users`:

```nix
# users/<usuario>.nix
home-manager.users.meuusuario = {
  imports = [
    ../../modules/user/apps/brave.nix
  ];
  # ... outras configurações
};
```

Ou diretamente no arquivo de home-manager do usuário:

```nix
# home.nix (ou arquivo equivalente do usuário)
{ imports = [ ../modules/user/apps/brave.nix ]; }
```

## Módulos disponíveis

### apps/

- **[brave.nix](apps/brave.nix)** — Instala o Brave Browser via nixpkgs e configura como browser padrão do usuário.

### dev/

_(em breve)_

### shell/

_(em breve)_
