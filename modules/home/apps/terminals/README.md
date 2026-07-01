# terminals

Módulos Home Manager para emuladores de terminal.

| Arquivo | Descrição |
|---------|-----------|
| [`tmux.nix`](tmux.nix) | Multiplexador de terminal com integração neovim |
| [`ghostty.nix`](ghostty.nix) | Emulador de terminal Ghostty |

---

## tmux — Atalhos de Teclado

Configuração baseada nas predefinições do [Omarchy](https://github.com/basecamp/omarchy),
com integração ao neovim via `vim-tmux-navigator`.

**Prefixo:** `Ctrl+Space` (alternativo: `Ctrl+b`)  
**Modo de teclas:** vi  
**Plugins:** `vim-tmux-navigator`, `yank`

### Navegação entre painéis / splits neovim

> Integração com neovim via `vim-tmux-navigator` — os mesmos atalhos funcionam
> dentro do neovim e entre painéis tmux sem distinção.

| Atalho | Ação |
|--------|------|
| `Ctrl+h` | Painel/split à esquerda |
| `Ctrl+j` | Painel/split abaixo |
| `Ctrl+k` | Painel/split acima |
| `Ctrl+l` | Painel/split à direita |
| `Ctrl+\` | Painel/split anterior |

### Painéis — criar e fechar

| Atalho | Ação |
|--------|------|
| `Alt+Enter` | Dividir verticalmente (diretório atual) |
| `Alt+Shift+Enter` | Dividir horizontalmente (diretório atual) |
| `Alt+Escape` | Fechar painel atual |
| `<prefixo> h` | Dividir verticalmente (diretório atual) |
| `<prefixo> v` | Dividir horizontalmente (diretório atual) |
| `<prefixo> x` | Fechar painel atual |

### Painéis — navegar e redimensionar

| Atalho | Ação |
|--------|------|
| `Ctrl+Alt+←` | Focar painel à esquerda |
| `Ctrl+Alt+→` | Focar painel à direita |
| `Ctrl+Alt+↑` | Focar painel acima |
| `Ctrl+Alt+↓` | Focar painel abaixo |
| `Ctrl+Alt+Shift+←` | Redimensionar painel (−5 colunas) |
| `Ctrl+Alt+Shift+→` | Redimensionar painel (+5 colunas) |
| `Ctrl+Alt+Shift+↑` | Redimensionar painel (+5 linhas) |
| `Ctrl+Alt+Shift+↓` | Redimensionar painel (−5 linhas) |

### Janelas

| Atalho | Ação |
|--------|------|
| `<prefixo> c` | Nova janela (diretório atual) |
| `<prefixo> r` | Renomear janela atual |
| `<prefixo> k` | Fechar janela atual |
| `Alt+1` … `Alt+9` | Ir direto para a janela N |
| `Alt+←` | Janela anterior |
| `Alt+→` | Próxima janela |
| `Alt+Shift+←` | Mover janela para a esquerda |
| `Alt+Shift+→` | Mover janela para a direita |

### Sessões

| Atalho | Ação |
|--------|------|
| `<prefixo> C` | Nova sessão (diretório atual) |
| `<prefixo> R` | Renomear sessão atual |
| `<prefixo> K` | Fechar sessão atual |
| `<prefixo> P` | Sessão anterior |
| `<prefixo> N` | Próxima sessão |
| `Alt+↑` | Sessão anterior |
| `Alt+↓` | Próxima sessão |

### Modo de cópia (vi)

Entrar no modo de cópia: `<prefixo> [`

| Atalho | Ação |
|--------|------|
| `v` | Iniciar seleção |
| `Ctrl+v` | Alternar seleção retangular |
| `y` | Copiar seleção para o clipboard do sistema e sair |

### Configuração

| Atalho | Ação |
|--------|------|
| `<prefixo> q` | Recarregar configuração do tmux |
