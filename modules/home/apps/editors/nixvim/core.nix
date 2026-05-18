# Camada core do nixvim: opções do editor, globals, keymaps e autocmds.
# Equivalente ao core do LazyVim (options.lua + keymaps.lua + autocmds.lua).
_:

{
  programs.nixvim = {
    globals = {
      mapleader = " ";
      maplocalleader = "\\";
    };

    opts = {
      # Numeração de linhas
      number = true;
      relativenumber = true;

      # Indentação
      expandtab = true;
      tabstop = 2;
      shiftwidth = 2;
      softtabstop = 2;
      shiftround = true;
      smartindent = true;

      # Busca
      hlsearch = true;
      incsearch = true;
      ignorecase = true;
      smartcase = true;

      # Visual
      termguicolors = true;
      cursorline = true;
      signcolumn = "yes";
      colorcolumn = "80";
      wrap = false;
      scrolloff = 8;
      sidescrolloff = 8;
      list = true;
      listchars = {
        tab = "» ";
        trail = "·";
        nbsp = "␣";
      };

      # Comportamento
      clipboard = "unnamedplus";
      undofile = true;
      swapfile = false;
      backup = false;
      updatetime = 200;
      timeoutlen = 300;
      splitright = true;
      splitbelow = true;

      # Performance
      lazyredraw = false;
    };

    keymaps = [
      # Limpar highlight de busca
      {
        key = "<Esc>";
        action = "<cmd>nohlsearch<CR>";
        mode = "n";
        options.desc = "Limpar highlight de busca";
      }

      # Navegação entre janelas (modo normal)
      {
        key = "<C-h>";
        action = "<C-w>h";
        mode = "n";
        options.desc = "Ir para janela à esquerda";
      }
      {
        key = "<C-j>";
        action = "<C-w>j";
        mode = "n";
        options.desc = "Ir para janela abaixo";
      }
      {
        key = "<C-k>";
        action = "<C-w>k";
        mode = "n";
        options.desc = "Ir para janela acima";
      }
      {
        key = "<C-l>";
        action = "<C-w>l";
        mode = "n";
        options.desc = "Ir para janela à direita";
      }

      # Redimensionar janelas
      {
        key = "<C-Up>";
        action = "<cmd>resize +2<CR>";
        mode = "n";
        options.desc = "Aumentar altura da janela";
      }
      {
        key = "<C-Down>";
        action = "<cmd>resize -2<CR>";
        mode = "n";
        options.desc = "Diminuir altura da janela";
      }
      {
        key = "<C-Left>";
        action = "<cmd>vertical resize -2<CR>";
        mode = "n";
        options.desc = "Diminuir largura da janela";
      }
      {
        key = "<C-Right>";
        action = "<cmd>vertical resize +2<CR>";
        mode = "n";
        options.desc = "Aumentar largura da janela";
      }

      # Navegação entre buffers
      {
        key = "<S-h>";
        action = "<cmd>bprevious<CR>";
        mode = "n";
        options.desc = "Buffer anterior";
      }
      {
        key = "<S-l>";
        action = "<cmd>bnext<CR>";
        mode = "n";
        options.desc = "Próximo buffer";
      }
      {
        key = "<leader>bd";
        action = "<cmd>bdelete<CR>";
        mode = "n";
        options.desc = "Fechar buffer";
      }

      # Mover linhas selecionadas (modo visual)
      {
        key = "<A-j>";
        action = ":m '>+1<CR>gv=gv";
        mode = "v";
        options = {
          desc = "Mover seleção para baixo";
          silent = true;
        };
      }
      {
        key = "<A-k>";
        action = ":m '<-2<CR>gv=gv";
        mode = "v";
        options = {
          desc = "Mover seleção para cima";
          silent = true;
        };
      }

      # Manter seleção após indentar
      {
        key = "<";
        action = "<gv";
        mode = "v";
        options.desc = "Desindantar e manter seleção";
      }
      {
        key = ">";
        action = ">gv";
        mode = "v";
        options.desc = "Indentar e manter seleção";
      }

      # Diagnósticos
      {
        key = "<leader>cd";
        action = "<cmd>lua vim.diagnostic.open_float()<CR>";
        mode = "n";
        options.desc = "Linha de diagnóstico";
      }
      {
        key = "[d";
        action = "<cmd>lua vim.diagnostic.goto_prev()<CR>";
        mode = "n";
        options.desc = "Diagnóstico anterior";
      }
      {
        key = "]d";
        action = "<cmd>lua vim.diagnostic.goto_next()<CR>";
        mode = "n";
        options.desc = "Próximo diagnóstico";
      }

      # Salvar arquivo
      {
        key = "<C-s>";
        action = "<cmd>w<CR><Esc>";
        mode = [
          "i"
          "n"
          "v"
        ];
        options = {
          desc = "Salvar arquivo";
          silent = true;
        };
      }

      # Sair
      {
        key = "<leader>qq";
        action = "<cmd>qa<CR>";
        mode = "n";
        options.desc = "Sair do Neovim";
      }

      # Novo arquivo
      {
        key = "<leader>fn";
        action = "<cmd>enew<CR>";
        mode = "n";
        options.desc = "Novo arquivo";
      }

      # Terminal
      {
        key = "<leader>gg";
        action = "<cmd>terminal lazygit<CR>";
        mode = "n";
        options.desc = "Abrir lazygit";
      }
    ];

    autoCmd = [
      # Remover espaços em branco ao salvar
      {
        event = "BufWritePre";
        pattern = "*";
        command = "%s/\\s\\+$//e";
      }
      # Voltar à posição do cursor ao reabrir arquivo
      {
        event = "BufReadPost";
        pattern = "*";
        command = ''
          if line("'\"") > 0 && line("'\"") <= line("$") | execute "normal! g'\"" | endif
        '';
      }
      # Highlight no yank
      {
        event = "TextYankPost";
        pattern = "*";
        command = "lua vim.highlight.on_yank()";
      }
      # Redimensionar janelas ao redimensionar o terminal
      {
        event = "VimResized";
        pattern = "*";
        command = "tabdo wincmd =";
      }
    ];
  };
}
