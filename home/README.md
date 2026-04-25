# home

Configurações Home Manager — geridas independentemente do NixOS via `home-manager switch`.

## Estrutura

| Arquivo/Pasta | Descrição |
|---------------|-----------|
| [`common.nix`](common.nix) | Configuração HM base aplicada a **todos** os usuários |
| [`modules/`](modules/) | Módulos HM reutilizáveis (importáveis pelos usuários) |
| [`users/`](users/) | Customizações específicas por usuário |

## Uso

### Aplicar configuração de um usuário

```bash
# Standalone (recomendado para o dia a dia):
home-manager switch --flake /etc/nixos#<usuario>@<host>

# Via lbnix (detecta usuário e host automaticamente):
lbnix home

# Especificando usuário/host manualmente:
lbnix home laercio@barbudus
```

### Adicionar customização para um novo usuário

1. Crie `home/users/<usuario>/home.nix` (use `home/users/laercio/home.nix` como exemplo).
2. Adicione em `flake.nix` (na seção `homeConfigurations`):
   ```nix
   // mkHomeAllHosts "<usuario>" [ ./home/users/<usuario>/home.nix ]
   ```

Usuários sem customização já herdam `home/common.nix` via `mkHomeAllHosts` em `flake.nix`.
