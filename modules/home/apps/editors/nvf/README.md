# nvf — Neovim

Configuração do Neovim via [nvf](https://github.com/notashelf/nvf).

**Leader:** `<Space>` · **LocalLeader:** `\`  
**Tema:** TokyoNight Moon  
**Plugins principais:** Telescope, Neo-tree, nvim-cmp, Lualine, BufferLine,
Gitsigns, Trouble, Flash, Snacks, persistence.nvim, mini.ai, mini.surround,
vim-tmux-navigator, vimtex, gregorio-nvim

---

## Atalhos de Teclado

### Navegação entre janelas / painéis tmux

Integração com tmux via `vim-tmux-navigator` — os mesmos atalhos funcionam
tanto dentro do neovim quanto entre painéis tmux.

| Atalho | Ação |
|--------|------|
| `Ctrl+h` | Janela/painel à esquerda |
| `Ctrl+j` | Janela/painel abaixo |
| `Ctrl+k` | Janela/painel acima |
| `Ctrl+l` | Janela/painel à direita |
| `Ctrl+\` | Janela/painel anterior |

### Janelas e splits

| Atalho | Modo | Ação |
|--------|------|------|
| `<leader>-` | Normal | Dividir janela horizontalmente |
| `<leader>\|` | Normal | Dividir janela verticalmente |
| `<leader>wd` | Normal | Fechar janela |
| `<leader>wm` | Normal | Maximizar/restaurar janela (zoom) |
| `Ctrl+↑` | Normal | Aumentar janela (+2 linhas) |
| `Ctrl+↓` | Normal | Diminuir janela (−2 linhas) |
| `Ctrl+←` | Normal | Diminuir janela (−2 colunas) |
| `Ctrl+→` | Normal | Aumentar janela (+2 colunas) |

### Buffers

| Atalho | Modo | Ação |
|--------|------|------|
| `Shift+h` | Normal | Buffer anterior |
| `Shift+l` | Normal | Próximo buffer |
| `<leader>bb` | Normal | Alternar buffer (último ativo) |
| `<leader>bd` | Normal | Fechar buffer |
| `<leader>bD` | Normal | Fechar buffer e janela |
| `<leader>bo` | Normal | Fechar outros buffers |
| `<leader>bp` | Normal | Fixar/desafixar buffer |
| `<leader>bP` | Normal | Fechar buffers não fixados |
| `<leader>br` | Normal | Fechar buffers à direita |
| `<leader>bl` | Normal | Fechar buffers à esquerda |
| `<leader>bj` | Normal | Selecionar buffer (pick) |
| `]B` | Normal | Mover buffer para a direita |
| `[B` | Normal | Mover buffer para a esquerda |

### Abas

| Atalho | Modo | Ação |
|--------|------|------|
| `<leader><tab><tab>` | Normal | Nova aba |
| `<leader><tab>d` | Normal | Fechar aba |
| `<leader><tab>]` | Normal | Próxima aba |
| `<leader><tab>[` | Normal | Aba anterior |
| `<leader><tab>f` | Normal | Primeira aba |
| `<leader><tab>l` | Normal | Última aba |

### Edição

| Atalho | Modo | Ação |
|--------|------|------|
| `Ctrl+s` | Normal/Insert/Visual | Salvar |
| `<leader>qq` | Normal | Sair de tudo (`:qa`) |
| `<leader>fn` | Normal | Novo arquivo |
| `<Esc>` | Normal | Limpar destaque de busca |
| `Alt+j` | Normal/Visual | Mover linha/seleção ↓ |
| `Alt+k` | Normal/Visual | Mover linha/seleção ↑ |
| `>` | Visual | Avançar indentação (mantém seleção) |
| `<` | Visual | Recuar indentação (mantém seleção) |
| `j` / `k` | Normal/Visual | Mover por linhas visuais (com contagem: linhas reais) |

### Explorador de arquivos (Neo-tree)

| Atalho | Modo | Ação |
|--------|------|------|
| `<leader>e` | Normal | Abrir/fechar explorador |
| `<leader>E` | Normal | Focar explorador |

### Busca (Telescope)

| Atalho | Modo | Ação |
|--------|------|------|
| `<leader>ff` | Normal | Buscar arquivos |
| `<leader>fg` | Normal | Busca por texto (live grep) |
| `<leader>fb` | Normal | Buffers abertos |
| `<leader>fh` | Normal | Ajuda (help tags) |
| `<leader>fo` | Normal | Arquivos recentes |
| `<leader>fc` | Normal | Comandos |
| `<leader>fr` | Normal | Retomar última busca |
| `<leader>ss` | Normal | Símbolos do documento (LSP) |
| `<leader>sS` | Normal | Símbolos do workspace (LSP) |
| `<leader>st` | Normal | Buscar TODO/FIXME |
| `<leader>sT` | Normal | Buscar todos os TODOs |
| `<leader>sr` | Normal/Visual | Buscar e substituir (GrugFar) |

### Navegação rápida (Flash)

| Atalho | Modo | Ação |
|--------|------|------|
| `s` | Normal/Visual/Operator | Salto rápido (flash) |
| `S` | Normal/Visual/Operator | Salto por nó Treesitter |
| `r` | Operator | Flash remoto |
| `R` | Operator/Visual | Busca por nó Treesitter |
| `Ctrl+s` | Command | Alternar Flash na busca |

### Resultados de busca

| Atalho | Modo | Ação |
|--------|------|------|
| `n` | Normal/Visual/Operator | Próximo resultado (direção inteligente) |
| `N` | Normal/Visual/Operator | Resultado anterior (direção inteligente) |
| `<leader>ur` | Normal | Redesenhar / limpar destaque de busca |

### LSP

| Atalho | Modo | Ação |
|--------|------|------|
| `gd` | Normal | Ir para definição |
| `gD` | Normal | Ir para declaração |
| `gI` | Normal | Ir para implementação |
| `gy` | Normal | Ir para definição de tipo |
| `K` | Normal | Documentação (hover) |
| `gr` | Normal | Referências (Telescope) |
| `<leader>cr` | Normal | Renomear símbolo |
| `<leader>ca` | Normal | Ação de código |
| `<leader>cf` | Normal/Visual | Formatar arquivo / seleção |
| `<leader>cR` | Normal | Renomear arquivo |
| `<leader>cs` | Normal | Símbolos (Trouble) |
| `<leader>cS` | Normal | Referências/definições LSP (Trouble) |

### Diagnósticos

| Atalho | Modo | Ação |
|--------|------|------|
| `<leader>cd` | Normal | Diagnóstico sob o cursor |
| `]d` / `[d` | Normal | Próximo / anterior diagnóstico |
| `]e` / `[e` | Normal | Próximo / anterior erro |
| `]w` / `[w` | Normal | Próximo / anterior warning |
| `<leader>xx` | Normal | Trouble: todos os diagnósticos |
| `<leader>xX` | Normal | Trouble: diagnósticos do buffer |
| `<leader>xL` | Normal | Trouble: lista de localização |
| `<leader>xQ` | Normal | Trouble: quickfix |
| `<leader>xt` | Normal | Trouble: TODO/FIXME |
| `<leader>xT` | Normal | Trouble: todos os TODOs |

### Quickfix

| Atalho | Modo | Ação |
|--------|------|------|
| `]q` / `[q` | Normal | Próximo / anterior quickfix |
| `]Q` / `[Q` | Normal | Último / primeiro quickfix |

### TODOs (todo-comments)

| Atalho | Modo | Ação |
|--------|------|------|
| `]t` / `[t` | Normal | Próximo / anterior TODO |

### Git (Gitsigns)

| Atalho | Modo | Ação |
|--------|------|------|
| `]h` / `[h` | Normal | Próxima / anterior mudança (hunk) |
| `]H` / `[H` | Normal | Próxima / anterior mudança (staged) |
| `<leader>ghs` | Normal | Stage hunk |
| `<leader>ghr` | Normal | Reset hunk |
| `<leader>ghp` | Normal | Preview hunk |
| `<leader>ghS` | Normal/Visual | Stage buffer |
| `<leader>ghu` | Normal | Desfazer stage do hunk |
| `<leader>ghR` | Normal/Visual | Reset buffer |
| `<leader>gb` | Normal | Blame da linha |
| `<leader>ghb` | Normal | Blame da linha (completo) |
| `<leader>ghB` | Normal | Blame do buffer |
| `<leader>ghd` | Normal | Diff (this) |
| `<leader>ghD` | Normal | Diff (último commit) |
| `ih` | Operator/Visual | Text-object: hunk |

### Git (LazyGit / Snacks)

| Atalho | Modo | Ação |
|--------|------|------|
| `<leader>gg` | Normal | Abrir LazyGit |
| `<leader>gG` | Normal | LazyGit (diretório atual) |
| `<leader>gf` | Normal | Log do arquivo atual (LazyGit) |
| `<leader>gl` | Normal | Log git |
| `<leader>gB` | Normal/Visual | Abrir arquivo no browser |
| `<leader>gY` | Normal/Visual | Copiar URL git |

### Sessões (persistence.nvim)

| Atalho | Modo | Ação |
|--------|------|------|
| `<leader>qs` | Normal | Restaurar sessão do diretório atual |
| `<leader>ql` | Normal | Restaurar última sessão |
| `<leader>qd` | Normal | Não salvar sessão ao sair |
| `<leader>qS` | Normal | Selecionar sessão |

### Terminal e utilitários (Snacks)

| Atalho | Modo | Ação |
|--------|------|------|
| `<leader>ft` | Normal | Terminal flutuante |
| `Ctrl+/` | Normal/Terminal | Alternar terminal flutuante |
| `<leader>n` | Normal | Histórico de notificações |
| `<leader>un` | Normal | Fechar notificações |
| `<leader>.` | Normal | Buffer temporário (scratch) |
| `<leader>S` | Normal | Selecionar buffer temporário |

### Toggles de UI (Snacks)

| Atalho | Ação |
|--------|------|
| `<leader>us` | Alternar corretor ortográfico |
| `<leader>uw` | Alternar quebra de linha |
| `<leader>uL` | Alternar números relativos |
| `<leader>ul` | Alternar números de linha |
| `<leader>ud` | Alternar diagnósticos |
| `<leader>uT` | Alternar highlight Treesitter |
| `<leader>uc` | Alternar ocultação de marcadores (conceal) |
| `<leader>ub` | Alternar fundo escuro/claro |
| `<leader>ug` | Alternar guias de indentação |
| `<leader>uS` | Alternar rolagem suave |
| `<leader>uf` | Alternar formatação ao salvar |
| `<leader>uh` | Alternar inlay hints (LSP) |
| `<leader>uz` | Alternar modo zen |
| `<leader>uZ` | Alternar zoom |

### Autocompletar (nvim-cmp)

| Atalho | Modo | Ação |
|--------|------|------|
| `Ctrl+n` | Insert | Próxima sugestão |
| `Ctrl+p` | Insert | Sugestão anterior |
| `Ctrl+b` | Insert | Rolar documentação ↑ |
| `Ctrl+f` | Insert | Rolar documentação ↓ |
| `Ctrl+Space` | Insert | Abrir menu de completar |
| `Ctrl+e` | Insert | Fechar menu |
| `Enter` | Insert | Confirmar seleção |

### Surround (mini.surround)

| Atalho | Modo | Ação |
|--------|------|------|
| `sa` | Normal/Visual | Adicionar delimitadores ao redor |
| `sd` | Normal | Remover delimitadores |
| `sr` | Normal | Substituir delimitadores |
| `sf` / `sF` | Normal | Encontrar delimitador (direita / esquerda) |
| `sh` | Normal | Destacar delimitadores |
| `sn` | Normal | Atualizar número de linhas |

### Text-objects extras (mini.ai)

Usados com operadores como `d`, `c`, `y`, `v` e motions `a`/`i`.

| Text-object | Descrição |
|-------------|-----------|
| `ao` / `io` | Ao redor / dentro de bloco, condicional ou laço |
| `af` / `if` | Ao redor / dentro de função |
| `ac` / `ic` | Ao redor / dentro de classe |
| `at` / `it` | Ao redor / dentro de tag HTML |
| `ad` / `id` | Ao redor / dentro de número |
| `ag` / `ig` | Arquivo inteiro |

### GABC / Gregorio (apenas em arquivos `.gabc`, `.nabc`, `.gregorio`)

| Atalho | Modo | Ação |
|--------|------|------|
| `<leader>cq` | Normal | Fix rápido (ação de código preferida pelo LSP) |
| `<leader>cQ` | Normal | Corrigir todos os diagnósticos automaticamente |
