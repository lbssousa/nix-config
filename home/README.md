# home

Configurações Home Manager — integradas ao NixOS como módulo do sistema.
O HM é aplicado automaticamente junto com `nixos-rebuild switch`.

## Estrutura

| Arquivo/Pasta | Descrição |
|---------------|-----------|
| [`common.nix`](common.nix) | Configuração HM base aplicada a **todos** os usuários |
| [`modules/`](../modules/home/) | Módulos HM reutilizáveis (importáveis pelos usuários) |
| [`users/`](users/) | Customizações específicas por usuário |

## Uso

### Aplicar configuração do sistema (inclui Home Manager)

```bash
# Via Just (detecta host e desktop ativos automaticamente):
just switch

# Especificando desktop explicitamente:
just switch plasma

# Ou diretamente via nixos-rebuild:
sudo nixos-rebuild switch --flake /etc/nixos
```

### Adicionar customização para um novo usuário

1. Crie `home/users/<usuario>/home.nix` (use `home/users/abutre/home.nix` como exemplo).
2. Adicione o arquivo ao índice do git:
   ```bash
   git add home/users/<usuario>/home.nix
   ```
3. O módulo [`modules/system/users/home-manager.nix`](../modules/system/users/home-manager.nix)
   detecta o arquivo via `lib.pathExists` e o importa automaticamente.

Usuários sem customização herdam apenas `home/common.nix`.
