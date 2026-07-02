{ pkgs, lib, ... }:

{
  programs.neovim.enable = lib.mkForce false;

  home.packages = with pkgs; [
    lazygit
    gcc
    stylua
    prettier
    shfmt
    nixfmt
    wl-clipboard
  ];

  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    globals = {
      mapleader = " ";
      maplocalleader = "\\";
      autoformat = true;
      vimtex_view_method = "zathura";
      vimtex_compiler_method = "latexmk";
      vimtex_mappings_prefix = "\\";
    };

    opts = {
      number = true;
      relativenumber = true;
      expandtab = true;
      tabstop = 2;
      shiftwidth = 2;
      smartindent = true;
      termguicolors = true;
      clipboard = "unnamedplus";
      colorcolumn = "80";
      scrolloff = 8;
      sidescrolloff = 8;
      cursorline = true;
      signcolumn = "yes";
      wrap = true;
      linebreak = true;
      breakindent = true;
      textwidth = 80;
      ignorecase = true;
      smartcase = true;
      splitbelow = true;
      splitright = true;
      undofile = true;
      undolevels = 10000;
      timeoutlen = 300;
      updatetime = 200;
      autowrite = true;
      conceallevel = 2;
      confirm = true;
      foldlevel = 99;
      foldmethod = "indent";
      foldtext = "";
      inccommand = "nosplit";
      list = true;
      pumblend = 10;
      pumheight = 10;
      ruler = false;
      shiftround = true;
      showmode = false;
      smoothscroll = true;
      splitkeep = "screen";
      virtualedit = "block";
      winminwidth = 5;
      fillchars = {
        eob = " ";
        foldopen = "▾";
        foldclose = "▸";
        fold = " ";
        foldsep = " ";
      };
      listchars = {
        tab = "» ";
        trail = "·";
        nbsp = "␣";
      };
    };

    # ── Autocommands ────────────────────────────────────────────────────────
    autoCmd = [
      {
        event = [ "TextYankPost" ];
        desc = "Realçar texto ao copiar";
        callback.__raw = ''
          function()
            vim.highlight.on_yank()
          end
        '';
      }
      {
        event = [ "CursorHold" ];
        desc = "Exibir diagnóstico sob o cursor";
        callback.__raw = ''
          function()
            vim.diagnostic.open_float(nil, {
              focusable = false,
              close_events = { "BufLeave", "CursorMoved", "InsertEnter", "FocusLost" },
              border = "rounded",
              source = "always",
              prefix = " ",
              scope = "cursor",
            })
          end
        '';
      }
      {
        event = [ "FileType" ];
        pattern = [
          "help"
          "man"
        ];
        desc = "Abrir help/man em janela vertical";
        callback.__raw = ''
          function()
            vim.cmd("wincmd L")
          end
        '';
      }
      {
        event = [
          "FocusGained"
          "TermClose"
          "TermLeave"
        ];
        desc = "Recarregar arquivo modificado externamente";
        callback.__raw = ''
          function()
            if vim.o.buftype ~= "nofile" then
              vim.cmd("checktime")
            end
          end
        '';
      }
      {
        event = [ "VimResized" ];
        desc = "Equalizar janelas ao redimensionar";
        callback.__raw = ''
          function()
            local tab = vim.fn.tabpagenr()
            vim.cmd("tabdo wincmd =")
            vim.cmd("tabnext " .. tab)
          end
        '';
      }
      {
        event = [ "BufReadPost" ];
        desc = "Restaurar última posição do cursor";
        callback.__raw = ''
          function(ev)
            if vim.tbl_contains({ "gitcommit" }, vim.bo[ev.buf].filetype) then
              return
            end
            local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
            local lcount = vim.api.nvim_buf_line_count(ev.buf)
            if mark[1] > 0 and mark[1] <= lcount then
              pcall(vim.api.nvim_win_set_cursor, 0, mark)
            end
          end
        '';
      }
      {
        event = [ "FileType" ];
        pattern = [
          "help"
          "man"
          "qf"
          "notify"
          "checkhealth"
          "lspinfo"
          "startuptime"
          "grug-far"
        ];
        desc = "Fechar com q em filetypes utilitários";
        callback.__raw = ''
          function(ev)
            vim.bo[ev.buf].buflisted = false
            vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = ev.buf, silent = true })
          end
        '';
      }
      {
        event = [ "FileType" ];
        pattern = [
          "text"
          "plaintex"
          "gitcommit"
          "markdown"
        ];
        desc = "Wrap e spell em filetypes de texto";
        callback.__raw = ''
          function()
            vim.opt_local.wrap = true
            vim.opt_local.spell = true
          end
        '';
      }
      {
        event = [ "FileType" ];
        pattern = [
          "json"
          "jsonc"
          "json5"
        ];
        desc = "Desabilitar conceallevel para JSON";
        callback.__raw = ''
          function()
            vim.opt_local.conceallevel = 0
          end
        '';
      }
      {
        event = [ "BufWritePre" ];
        desc = "Criar diretórios intermediários ao salvar";
        callback.__raw = ''
          function(ev)
            if ev.match:match("^%w%w+:[\\/][\\/]") then
              return
            end
            local file = vim.uv.fs_realpath(ev.match) or ev.match
            vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
          end
        '';
      }
      {
        event = [ "BufWritePre" ];
        desc = "Formatar ao salvar quando autoformat estiver ativo";
        callback.__raw = ''
          function(ev)
            if vim.g.autoformat == false then
              return
            end
            if vim.b[ev.buf].autoformat == false then
              return
            end
            require("conform").format({
              bufnr = ev.buf,
              timeout_ms = 500,
              lsp_fallback = true,
            })
          end
        '';
      }
      {
        event = [ "LspAttach" ];
        desc = "Keymaps extras para gregorio-lsp";
        callback.__raw = ''
          function(args)
            local client = vim.lsp.get_client_by_id(args.data.client_id)
            if not client or client.name ~= "gregorio-lsp" then
              return
            end

            local bufnr = args.buf

            vim.keymap.set("n", "<leader>cq", function()
              vim.lsp.buf.code_action({
                apply = true,
                filter = function(action)
                  return action.isPreferred
                end,
              })
            end, { buffer = bufnr, desc = "GABC: fix rápido (diagnóstico)" })

            vim.keymap.set("n", "<leader>cQ", function()
              local diags = vim.diagnostic.get(bufnr)
              if #diags == 0 then
                vim.notify("Sem diagnósticos para corrigir.", vim.log.levels.INFO)
                return
              end

              table.sort(diags, function(a, b)
                if a.lnum ~= b.lnum then
                  return a.lnum > b.lnum
                end
                return a.col > b.col
              end)

              local fixed = 0

              local function apply_next(idx)
                if idx > #diags then
                  local msg = fixed > 0
                      and (fixed .. " diagnóstico(s) corrigido(s).")
                    or "Nenhum fix disponível."
                  vim.notify(msg, fixed > 0 and vim.log.levels.INFO or vim.log.levels.WARN)
                  return
                end

                local d = diags[idx]
                local lsp_diag = d.user_data and d.user_data.lsp
                if not (lsp_diag and lsp_diag.data and lsp_diag.data.fix) then
                  apply_next(idx + 1)
                  return
                end

                local params = {
                  textDocument = vim.lsp.util.make_text_document_params(bufnr),
                  range = {
                    start = { line = d.lnum, character = d.col },
                    ["end"] = { line = d.end_lnum or d.lnum, character = d.end_col or d.col },
                  },
                  context = { diagnostics = { lsp_diag }, only = { "quickfix" } },
                }

                client.request("textDocument/codeAction", params, function(err, result)
                  if not err and result then
                    for _, action in ipairs(result) do
                      if action.isPreferred and action.edit then
                        vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding)
                        fixed = fixed + 1
                        break
                      end
                    end
                  end
                  apply_next(idx + 1)
                end, bufnr)
              end

              apply_next(1)
            end, { buffer = bufnr, desc = "GABC: fix todos (auto-fix)" })
          end
        '';
      }
    ];

    # ── Keymaps ─────────────────────────────────────────────────────────────
    keymaps = [
      # Navegação tmux
      {
        mode = "n";
        key = "<C-h>";
        action = "<Cmd>TmuxNavigateLeft<CR>";
        options.desc = "Painel/janela esquerda";
      }
      {
        mode = "n";
        key = "<C-j>";
        action = "<Cmd>TmuxNavigateDown<CR>";
        options.desc = "Painel/janela abaixo";
      }
      {
        mode = "n";
        key = "<C-k>";
        action = "<Cmd>TmuxNavigateUp<CR>";
        options.desc = "Painel/janela acima";
      }
      {
        mode = "n";
        key = "<C-l>";
        action = "<Cmd>TmuxNavigateRight<CR>";
        options.desc = "Painel/janela direita";
      }
      {
        mode = "n";
        key = "<C-\\>";
        action = "<Cmd>TmuxNavigatePrevious<CR>";
        options.desc = "Painel/janela anterior";
      }

      # Redimensionar janelas
      {
        mode = "n";
        key = "<C-Up>";
        action = "<cmd>resize +2<CR>";
        options.desc = "Aumentar janela";
      }
      {
        mode = "n";
        key = "<C-Down>";
        action = "<cmd>resize -2<CR>";
        options.desc = "Diminuir janela";
      }
      {
        mode = "n";
        key = "<C-Left>";
        action = "<cmd>vertical resize -2<CR>";
        options.desc = "Diminuir janela (h)";
      }
      {
        mode = "n";
        key = "<C-Right>";
        action = "<cmd>vertical resize +2<CR>";
        options.desc = "Aumentar janela (h)";
      }

      # Indentação visual
      {
        mode = "v";
        key = "<";
        action = "<gv";
        options.desc = "Recuar";
      }
      {
        mode = "v";
        key = ">";
        action = ">gv";
        options.desc = "Avançar";
      }

      # Mover linhas
      {
        mode = "n";
        key = "<A-j>";
        action = "<cmd>m .+1<CR>==";
        options.desc = "Mover linha ↓";
      }
      {
        mode = "n";
        key = "<A-k>";
        action = "<cmd>m .-2<CR>==";
        options.desc = "Mover linha ↑";
      }
      {
        mode = "v";
        key = "<A-j>";
        action = ":m '>+1<CR>gv=gv";
        options.desc = "Mover seleção ↓";
      }
      {
        mode = "v";
        key = "<A-k>";
        action = ":m '<-2<CR>gv=gv";
        options.desc = "Mover seleção ↑";
      }

      # Geral
      {
        mode = "n";
        key = "<Esc>";
        action = "<cmd>nohlsearch<CR>";
      }
      {
        mode = [
          "n"
          "i"
          "v"
        ];
        key = "<C-s>";
        action = "<cmd>w<CR><Esc>";
        options.desc = "Salvar";
      }
      {
        mode = "n";
        key = "<leader>qq";
        action = "<cmd>qa<CR>";
        options.desc = "Sair (todo)";
      }
      {
        mode = "n";
        key = "<leader>fn";
        action = "<cmd>enew<CR>";
        options.desc = "Novo arquivo";
      }

      # Buffers
      {
        mode = "n";
        key = "<S-h>";
        action = "<cmd>bprevious<CR>";
        options.desc = "Buffer anterior";
      }
      {
        mode = "n";
        key = "<S-l>";
        action = "<cmd>bnext<CR>";
        options.desc = "Próximo buffer";
      }
      {
        mode = "n";
        key = "<leader>bd";
        action = "<cmd>bdelete<CR>";
        options.desc = "Fechar buffer";
      }
      {
        mode = "n";
        key = "<leader>bo";
        action = "<cmd>%bdelete|edit#|bdelete#<CR>";
        options.desc = "Fechar outros buffers";
      }
      {
        mode = "n";
        key = "<leader>bb";
        action = "<cmd>e #<CR>";
        options.desc = "Alternar buffer";
      }
      {
        mode = "n";
        key = "<leader>bD";
        action = "<cmd>bd<CR>";
        options.desc = "Fechar buffer e janela";
      }
      {
        mode = "n";
        key = "<leader>bp";
        action = "<cmd>BufferLineTogglePin<CR>";
        options.desc = "Fixar buffer";
      }
      {
        mode = "n";
        key = "<leader>bP";
        action = "<cmd>BufferLineGroupClose ungrouped<CR>";
        options.desc = "Fechar buffers não fixados";
      }
      {
        mode = "n";
        key = "<leader>br";
        action = "<cmd>BufferLineCloseRight<CR>";
        options.desc = "Fechar buffers à direita";
      }
      {
        mode = "n";
        key = "<leader>bl";
        action = "<cmd>BufferLineCloseLeft<CR>";
        options.desc = "Fechar buffers à esquerda";
      }
      {
        mode = "n";
        key = "]B";
        action = "<cmd>BufferLineMoveNext<CR>";
        options.desc = "Mover buffer para direita";
      }
      {
        mode = "n";
        key = "[B";
        action = "<cmd>BufferLineMovePrev<CR>";
        options.desc = "Mover buffer para esquerda";
      }
      {
        mode = "n";
        key = "<leader>bj";
        action = "<cmd>BufferLinePick<CR>";
        options.desc = "Selecionar buffer";
      }

      # Movimento visual j/k
      {
        mode = [
          "n"
          "x"
        ];
        key = "j";
        action.__raw = ''
          function()
            return vim.v.count == 0 and "gj" or "j"
          end
        '';
        options = {
          expr = true;
          silent = true;
          desc = "↓ (linha visual)";
        };
      }
      {
        mode = [
          "n"
          "x"
        ];
        key = "k";
        action.__raw = ''
          function()
            return vim.v.count == 0 and "gk" or "k"
          end
        '';
        options = {
          expr = true;
          silent = true;
          desc = "↑ (linha visual)";
        };
      }

      # Redesenhar
      {
        mode = "n";
        key = "<leader>ur";
        action = "<cmd>nohlsearch<bar>diffupdate<bar>normal! <C-l><CR>";
        options.desc = "Redesenhar / limpar busca";
      }

      # Busca n/N consistente com direção
      {
        mode = [
          "n"
          "x"
          "o"
        ];
        key = "n";
        action.__raw = ''
          function()
            return vim.v.searchforward == 1 and "nzv" or "Nzv"
          end
        '';
        options = {
          expr = true;
          silent = true;
          desc = "Próx. resultado da busca";
        };
      }
      {
        mode = [
          "n"
          "x"
          "o"
        ];
        key = "N";
        action.__raw = ''
          function()
            return vim.v.searchforward == 1 and "Nzv" or "nzv"
          end
        '';
        options = {
          expr = true;
          silent = true;
          desc = "Result. anterior da busca";
        };
      }

      # Diagnósticos
      {
        mode = "n";
        key = "]e";
        action.__raw = "function() vim.diagnostic.goto_next({ severity = vim.diagnostic.severity.ERROR }) end";
        options.desc = "Próximo erro";
      }
      {
        mode = "n";
        key = "[e";
        action.__raw = "function() vim.diagnostic.goto_prev({ severity = vim.diagnostic.severity.ERROR }) end";
        options.desc = "Erro anterior";
      }
      {
        mode = "n";
        key = "]w";
        action.__raw = "function() vim.diagnostic.goto_next({ severity = vim.diagnostic.severity.WARN }) end";
        options.desc = "Próximo warning";
      }
      {
        mode = "n";
        key = "[w";
        action.__raw = "function() vim.diagnostic.goto_prev({ severity = vim.diagnostic.severity.WARN }) end";
        options.desc = "Warning anterior";
      }
      {
        mode = "n";
        key = "]q";
        action = "<cmd>cnext<CR>";
        options.desc = "Próximo quickfix";
      }
      {
        mode = "n";
        key = "[q";
        action = "<cmd>cprev<CR>";
        options.desc = "Quickfix anterior";
      }
      {
        mode = "n";
        key = "]Q";
        action = "<cmd>clast<CR>";
        options.desc = "Último quickfix";
      }
      {
        mode = "n";
        key = "[Q";
        action = "<cmd>cfirst<CR>";
        options.desc = "Primeiro quickfix";
      }
      {
        mode = "n";
        key = "<leader>cd";
        action.__raw = "vim.diagnostic.open_float";
        options.desc = "Diagnóstico sob cursor";
      }
      {
        mode = "n";
        key = "[d";
        action.__raw = "vim.diagnostic.goto_prev";
        options.desc = "Diagnóstico anterior";
      }
      {
        mode = "n";
        key = "]d";
        action.__raw = "vim.diagnostic.goto_next";
        options.desc = "Próximo diagnóstico";
      }

      # Janelas
      {
        mode = "n";
        key = "<leader>-";
        action = "<cmd>split<CR>";
        options.desc = "Dividir janela (horizontal)";
      }
      {
        mode = "n";
        key = "<leader>|";
        action = "<cmd>vsplit<CR>";
        options.desc = "Dividir janela (vertical)";
      }
      {
        mode = "n";
        key = "<leader>wd";
        action = "<cmd>close<CR>";
        options.desc = "Fechar janela";
      }

      # Abas
      {
        mode = "n";
        key = "<leader><tab><tab>";
        action = "<cmd>tabnew<CR>";
        options.desc = "Nova aba";
      }
      {
        mode = "n";
        key = "<leader><tab>d";
        action = "<cmd>tabclose<CR>";
        options.desc = "Fechar aba";
      }
      {
        mode = "n";
        key = "<leader><tab>]";
        action = "<cmd>tabnext<CR>";
        options.desc = "Próxima aba";
      }
      {
        mode = "n";
        key = "<leader><tab>[";
        action = "<cmd>tabprevious<CR>";
        options.desc = "Aba anterior";
      }
      {
        mode = "n";
        key = "<leader><tab>f";
        action = "<cmd>tabfirst<CR>";
        options.desc = "Primeira aba";
      }
      {
        mode = "n";
        key = "<leader><tab>l";
        action = "<cmd>tablast<CR>";
        options.desc = "Última aba";
      }

      # Neo-tree
      {
        mode = "n";
        key = "<leader>e";
        action = "<cmd>Neotree toggle<CR>";
        options.desc = "Explorador de arquivos";
      }
      {
        mode = "n";
        key = "<leader>E";
        action = "<cmd>Neotree focus<CR>";
        options.desc = "Focar explorador";
      }

      # Flash
      {
        mode = [
          "n"
          "x"
          "o"
        ];
        key = "s";
        action.__raw = ''function() require("flash").jump() end'';
        options.desc = "Flash";
      }
      {
        mode = [
          "n"
          "x"
          "o"
        ];
        key = "S";
        action.__raw = ''function() require("flash").treesitter() end'';
        options.desc = "Flash Treesitter";
      }
      {
        mode = "o";
        key = "r";
        action.__raw = ''function() require("flash").remote() end'';
        options.desc = "Flash Remote";
      }
      {
        mode = [
          "o"
          "x"
        ];
        key = "R";
        action.__raw = ''function() require("flash").treesitter_search() end'';
        options.desc = "Flash Treesitter Search";
      }
      {
        mode = "c";
        key = "<C-s>";
        action.__raw = ''function() require("flash").toggle() end'';
        options.desc = "Flash: alternar em busca";
      }

      # todo-comments
      {
        mode = "n";
        key = "]t";
        action.__raw = ''function() require("todo-comments").jump_next() end'';
        options.desc = "Próximo TODO";
      }
      {
        mode = "n";
        key = "[t";
        action.__raw = ''function() require("todo-comments").jump_prev() end'';
        options.desc = "TODO anterior";
      }
      {
        mode = "n";
        key = "<leader>st";
        action = "<cmd>TodoTelescope keywords=TODO,FIXME<CR>";
        options.desc = "Buscar TODO/FIXME";
      }
      {
        mode = "n";
        key = "<leader>sT";
        action = "<cmd>TodoTelescope<CR>";
        options.desc = "Buscar todos os TODOs";
      }

      # Trouble
      {
        mode = "n";
        key = "<leader>xx";
        action = "<cmd>Trouble diagnostics toggle<CR>";
        options.desc = "Diagnósticos";
      }
      {
        mode = "n";
        key = "<leader>xX";
        action = "<cmd>Trouble diagnostics toggle filter.buf=0<CR>";
        options.desc = "Diagnósticos (buffer)";
      }
      {
        mode = "n";
        key = "<leader>xL";
        action = "<cmd>Trouble loclist toggle<CR>";
        options.desc = "Lista de localização";
      }
      {
        mode = "n";
        key = "<leader>xQ";
        action = "<cmd>Trouble qflist toggle<CR>";
        options.desc = "Quickfix";
      }
      {
        mode = "n";
        key = "<leader>xt";
        action = "<cmd>TodoTrouble keywords=TODO,FIXME<CR>";
        options.desc = "TODO/FIXME (Trouble)";
      }
      {
        mode = "n";
        key = "<leader>xT";
        action = "<cmd>TodoTrouble<CR>";
        options.desc = "Todos os TODOs (Trouble)";
      }
      {
        mode = "n";
        key = "<leader>cs";
        action = "<cmd>Trouble symbols toggle<CR>";
        options.desc = "Símbolos";
      }
      {
        mode = "n";
        key = "<leader>cS";
        action = "<cmd>Trouble lsp toggle<CR>";
        options.desc = "Referências/definições LSP";
      }

      # Gitsigns
      {
        mode = "n";
        key = "]h";
        action = "<cmd>Gitsigns next_hunk<CR>";
        options.desc = "Próxima mudança";
      }
      {
        mode = "n";
        key = "[h";
        action = "<cmd>Gitsigns prev_hunk<CR>";
        options.desc = "Mudança anterior";
      }
      {
        mode = "n";
        key = "<leader>ghs";
        action = "<cmd>Gitsigns stage_hunk<CR>";
        options.desc = "Stage hunk";
      }
      {
        mode = "n";
        key = "<leader>ghr";
        action = "<cmd>Gitsigns reset_hunk<CR>";
        options.desc = "Reset hunk";
      }
      {
        mode = "n";
        key = "<leader>ghp";
        action = "<cmd>Gitsigns preview_hunk<CR>";
        options.desc = "Preview hunk";
      }
      {
        mode = "n";
        key = "<leader>gb";
        action = "<cmd>Gitsigns blame_line<CR>";
        options.desc = "Blame linha";
      }
      {
        mode = "n";
        key = "]H";
        action = "<cmd>Gitsigns next_hunk<CR>";
        options.desc = "Próxima mudança (staged)";
      }
      {
        mode = "n";
        key = "[H";
        action = "<cmd>Gitsigns prev_hunk<CR>";
        options.desc = "Mudança anterior (staged)";
      }
      {
        mode = [
          "n"
          "v"
        ];
        key = "<leader>ghS";
        action = "<cmd>Gitsigns stage_buffer<CR>";
        options.desc = "Stage buffer";
      }
      {
        mode = "n";
        key = "<leader>ghu";
        action = "<cmd>Gitsigns undo_stage_hunk<CR>";
        options.desc = "Desfazer stage hunk";
      }
      {
        mode = [
          "n"
          "v"
        ];
        key = "<leader>ghR";
        action = "<cmd>Gitsigns reset_buffer<CR>";
        options.desc = "Reset buffer";
      }
      {
        mode = "n";
        key = "<leader>ghb";
        action.__raw = ''function() require("gitsigns").blame_line({ full = true }) end'';
        options.desc = "Blame linha (completo)";
      }
      {
        mode = "n";
        key = "<leader>ghB";
        action = "<cmd>Gitsigns blame<CR>";
        options.desc = "Blame buffer";
      }
      {
        mode = "n";
        key = "<leader>ghd";
        action = "<cmd>Gitsigns diffthis<CR>";
        options.desc = "Diff (this)";
      }
      {
        mode = "n";
        key = "<leader>ghD";
        action.__raw = ''function() require("gitsigns").diffthis("~") end'';
        options.desc = "Diff (último commit)";
      }
      {
        mode = [
          "o"
          "x"
        ];
        key = "ih";
        action = ":<C-U>Gitsigns select_hunk<CR>";
        options.desc = "Text-object hunk";
      }

      # Grug-far
      {
        mode = [
          "n"
          "v"
        ];
        key = "<leader>sr";
        action = "<cmd>GrugFar<CR>";
        options.desc = "Buscar e substituir";
      }

      # Persistence
      {
        mode = "n";
        key = "<leader>qs";
        action.__raw = ''function() require("persistence").load() end'';
        options.desc = "Restaurar sessão";
      }
      {
        mode = "n";
        key = "<leader>ql";
        action.__raw = ''function() require("persistence").load({ last = true }) end'';
        options.desc = "Restaurar última sessão";
      }
      {
        mode = "n";
        key = "<leader>qd";
        action.__raw = ''function() require("persistence").stop() end'';
        options.desc = "Não salvar sessão";
      }
      {
        mode = "n";
        key = "<leader>qS";
        action.__raw = ''function() require("persistence").select() end'';
        options.desc = "Selecionar sessão";
      }

      # Telescope
      {
        mode = "n";
        key = "<leader>ff";
        action = "<cmd>Telescope find_files<CR>";
        options.desc = "Arquivos";
      }
      {
        mode = "n";
        key = "<leader>fg";
        action = "<cmd>Telescope live_grep<CR>";
        options.desc = "Grep ao vivo";
      }
      {
        mode = "n";
        key = "<leader>fb";
        action = "<cmd>Telescope buffers<CR>";
        options.desc = "Buffers abertos";
      }
      {
        mode = "n";
        key = "<leader>fh";
        action = "<cmd>Telescope help_tags<CR>";
        options.desc = "Ajuda";
      }
      {
        mode = "n";
        key = "<leader>fo";
        action = "<cmd>Telescope oldfiles<CR>";
        options.desc = "Arquivos recentes";
      }
      {
        mode = "n";
        key = "<leader>fc";
        action = "<cmd>Telescope commands<CR>";
        options.desc = "Comandos";
      }
      {
        mode = "n";
        key = "<leader>fr";
        action = "<cmd>Telescope resume<CR>";
        options.desc = "Retomar busca";
      }
      {
        mode = "n";
        key = "<leader>ss";
        action = "<cmd>Telescope lsp_document_symbols<CR>";
        options.desc = "Símbolos (documento)";
      }
      {
        mode = "n";
        key = "<leader>sS";
        action = "<cmd>Telescope lsp_workspace_symbols<CR>";
        options.desc = "Símbolos (workspace)";
      }

      # Snacks
      {
        mode = "n";
        key = "<leader>n";
        action.__raw = "function() Snacks.notifier.show_history() end";
        options.desc = "Histórico de notificações";
      }
      {
        mode = "n";
        key = "<leader>un";
        action.__raw = "function() Snacks.notifier.hide() end";
        options.desc = "Fechar notificações";
      }
      {
        mode = "n";
        key = "<leader>ft";
        action.__raw = "function() Snacks.terminal() end";
        options.desc = "Terminal flutuante";
      }
      {
        mode = [
          "n"
          "t"
        ];
        key = "<C-/>";
        action.__raw = "function() Snacks.terminal.toggle() end";
        options.desc = "Terminal flutuante";
      }
      {
        mode = "n";
        key = "<leader>gg";
        action.__raw = "function() Snacks.lazygit() end";
        options.desc = "LazyGit";
      }
      {
        mode = "n";
        key = "<leader>gG";
        action.__raw = "function() Snacks.lazygit({ cwd = vim.uv.cwd() }) end";
        options.desc = "LazyGit (diretório atual)";
      }
      {
        mode = "n";
        key = "<leader>gf";
        action.__raw = "function() Snacks.lazygit.log_file() end";
        options.desc = "LazyGit (arquivo atual)";
      }
      {
        mode = "n";
        key = "<leader>gl";
        action.__raw = "function() Snacks.lazygit.log() end";
        options.desc = "Log git";
      }
      {
        mode = [
          "n"
          "x"
        ];
        key = "<leader>gB";
        action.__raw = "function() Snacks.gitbrowse() end";
        options.desc = "Abrir no browser";
      }
      {
        mode = [
          "n"
          "x"
        ];
        key = "<leader>gY";
        action.__raw = ''
          function()
            Snacks.gitbrowse({
              open = function(url)
                vim.fn.setreg("+", url)
              end,
              notify = false,
            })
          end
        '';
        options.desc = "Copiar URL git";
      }
      {
        mode = "n";
        key = "<leader>.";
        action.__raw = "function() Snacks.scratch() end";
        options.desc = "Buffer temporário";
      }
      {
        mode = "n";
        key = "<leader>S";
        action.__raw = "function() Snacks.scratch.select() end";
        options.desc = "Selecionar buffer temporário";
      }

      # LSP
      {
        mode = "n";
        key = "gd";
        action.__raw = "vim.lsp.buf.definition";
        options.desc = "Ir para definição";
      }
      {
        mode = "n";
        key = "gD";
        action.__raw = "vim.lsp.buf.declaration";
        options.desc = "Ir para declaração";
      }
      {
        mode = "n";
        key = "gI";
        action.__raw = "vim.lsp.buf.implementation";
        options.desc = "Ir para implementação";
      }
      {
        mode = "n";
        key = "gy";
        action.__raw = "vim.lsp.buf.type_definition";
        options.desc = "Ir para tipo";
      }
      {
        mode = "n";
        key = "K";
        action.__raw = "vim.lsp.buf.hover";
        options.desc = "Hover";
      }
      {
        mode = "n";
        key = "<leader>cr";
        action.__raw = "vim.lsp.buf.rename";
        options.desc = "Renomear símbolo";
      }
      {
        mode = "n";
        key = "<leader>ca";
        action.__raw = "vim.lsp.buf.code_action";
        options.desc = "Ação de código";
      }
      {
        mode = "n";
        key = "gr";
        action = "<cmd>Telescope lsp_references<CR>";
        options.desc = "Referências (Telescope)";
      }
      {
        mode = "n";
        key = "<leader>cf";
        action.__raw = ''function() require("conform").format({ lsp_fallback = true }) end'';
        options.desc = "Formatar arquivo";
      }
      {
        mode = "v";
        key = "<leader>cf";
        action.__raw = ''function() require("conform").format({ lsp_fallback = true }) end'';
        options.desc = "Formatar seleção";
      }
      {
        mode = "n";
        key = "<leader>cR";
        action.__raw = ''
          function()
            local old_name = vim.fn.expand("%")
            vim.ui.input({ prompt = "Novo nome: ", default = old_name }, function(new_name)
              if not new_name or new_name == old_name then
                return
              end
              vim.lsp.util.rename(old_name, new_name, {})
              vim.api.nvim_buf_set_name(0, new_name)
              vim.cmd("keepalt saveas! " .. new_name)
            end)
          end
        '';
        options.desc = "Renomear arquivo";
      }
    ];

    # ── Snacks toggles (precisam de vim.schedule) ────────────────────────────
    extraConfigLuaPost = ''
      vim.schedule(function()
        local t = Snacks.toggle
        t.option("spell", { name = "Corretor Ortográfico" }):map("<leader>us")
        t.option("wrap", { name = "Quebra de Linha" }):map("<leader>uw")
        t.option("relativenumber", { name = "Número Relativo" }):map("<leader>uL")
        t.diagnostics():map("<leader>ud")
        t.line_number():map("<leader>ul")
        t.treesitter():map("<leader>uT")
        t.option("conceallevel", {
          off = 0,
          on = vim.o.conceallevel > 0 and vim.o.conceallevel or 2,
          name = "Ocultar Marcadores",
        }):map("<leader>uc")
        t.option("background", { off = "light", on = "dark", name = "Fundo Escuro" }):map("<leader>ub")
        t.indent():map("<leader>ug")
        t.scroll():map("<leader>uS")
        t.zoom():map("<leader>wm")
        t.zoom():map("<leader>uZ")
        t.zen():map("<leader>uz")
        if vim.lsp.inlay_hint then
          t.inlay_hints():map("<leader>uh")
        end
        t.new({
          name = "Formatação ao Salvar",
          get = function()
            return vim.g.autoformat ~= false
          end,
          set = function(state)
            vim.g.autoformat = state
          end,
        }):map("<leader>uf")
      end)
    '';

    # ── Colorscheme ─────────────────────────────────────────────────────────
    colorschemes.tokyonight = {
      enable = true;
      settings = {
        style = "moon";
        transparent = false;
        terminal_colors = true;
      };
    };

    # ── Treesitter ───────────────────────────────────────────────────────────
    plugins.treesitter = {
      enable = true;
      settings.highlight.enable = true;
      grammarPackages =
        with pkgs.vimPlugins.nvim-treesitter.builtGrammars;
        [
          bash
          css
          html
          json
          lua
          markdown
          markdown_inline
          nix
          rust
          toml
          typescript
          yaml
        ]
        ++ [ pkgs.tree-sitter-gregorio-nvim ];
    };

    plugins.treesitter-context.enable = true;

    # ── Ícones ───────────────────────────────────────────────────────────────
    plugins.web-devicons.enable = true;

    # ── Statusline ───────────────────────────────────────────────────────────
    plugins.lualine = {
      enable = true;
      settings.options = {
        theme = "tokyonight";
        globalstatus = true;
        disabled_filetypes.statusline = [
          "dashboard"
          "alpha"
          "snacks_dashboard"
        ];
      };
    };

    # ── Bufferline ───────────────────────────────────────────────────────────
    plugins.bufferline = {
      enable = true;
      settings.options = {
        diagnostics = "nvim_lsp";
        always_show_bufferline = false;
        offsets = [
          {
            filetype = "neo-tree";
            text = "Neo-tree";
            highlight = "Directory";
            text_align = "left";
          }
        ];
      };
    };

    # ── Neo-tree ─────────────────────────────────────────────────────────────
    plugins.neo-tree = {
      enable = true;
      settings = {
        close_if_last_window = true;
        popup_border_style = "rounded";
        window = {
          position = "left";
          width = 30;
        };
        default_component_configs.indent.with_expanders = true;
      };
    };

    # ── Which-key ────────────────────────────────────────────────────────────
    plugins.which-key = {
      enable = true;
      settings = {
        preset = "helix";
        spec = [
          {
            __unkeyed-1 = "<leader>f";
            group = "arquivo";
          }
          {
            __unkeyed-1 = "<leader>g";
            group = "git";
          }
          {
            __unkeyed-1 = "<leader>gh";
            group = "hunks git";
          }
          {
            __unkeyed-1 = "<leader>c";
            group = "código";
          }
          {
            __unkeyed-1 = "<leader>b";
            group = "buffer";
          }
          {
            __unkeyed-1 = "<leader>q";
            group = "sair/sessão";
          }
          {
            __unkeyed-1 = "<leader>s";
            group = "buscar";
          }
          {
            __unkeyed-1 = "<leader>u";
            group = "ui";
          }
          {
            __unkeyed-1 = "<leader>w";
            group = "janelas";
          }
          {
            __unkeyed-1 = "<leader>x";
            group = "diagnósticos";
          }
          {
            __unkeyed-1 = "<leader><tab>";
            group = "abas";
          }
        ];
      };
    };

    # ── Noice ────────────────────────────────────────────────────────────────
    plugins.noice = {
      enable = true;
      settings = {
        lsp.override = {
          "vim.lsp.util.convert_input_to_markdown_lines" = true;
          "vim.lsp.util.stylize_markdown" = true;
          "cmp.entry.get_documentation" = true;
        };
        presets = {
          bottom_search = true;
          command_palette = true;
          long_message_to_split = true;
          inc_rename = false;
          lsp_doc_border = true;
        };
      };
    };

    # ── Telescope ────────────────────────────────────────────────────────────
    plugins.telescope.enable = true;

    # ── Flash ────────────────────────────────────────────────────────────────
    plugins.flash = {
      enable = true;
      settings.modes.char.highlight.backdrop = false;
    };

    # ── Grug-far ─────────────────────────────────────────────────────────────
    plugins.grug-far.enable = true;

    # ── Snacks ───────────────────────────────────────────────────────────────
    plugins.snacks = {
      enable = true;
      settings = {
        bigfile.enabled = true;
        quickfile.enabled = true;
        statuscolumn.enabled = false;

        notifier = {
          enabled = true;
          timeout = 3000;
          style = "fancy";
        };

        dashboard = {
          sections = [
            { section = "header"; }
            {
              section = "keys";
              gap = 1;
              padding = 1;
            }
          ];
          preset = {
            header = ''
              ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗
              ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║
              ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║
              ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║
              ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║
              ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝
            '';
            keys = [
              {
                icon = " ";
                key = "f";
                desc = "Buscar Arquivo";
                action = ":Telescope find_files";
              }
              {
                icon = " ";
                key = "n";
                desc = "Novo Arquivo";
                action = ":ene | startinsert";
              }
              {
                icon = " ";
                key = "g";
                desc = "Buscar Texto";
                action = ":Telescope live_grep";
              }
              {
                icon = " ";
                key = "r";
                desc = "Arquivos Recentes";
                action = ":Telescope oldfiles";
              }
              {
                icon = " ";
                key = "s";
                desc = "Restaurar Sessão";
                section = "session";
              }
              {
                icon = " ";
                key = "q";
                desc = "Sair";
                action = ":qa";
              }
            ];
          };
        };

        indent = {
          enabled = true;
          indent.char = "│";
          scope = {
            enabled = true;
            char = "│";
          };
        };

        scope.enabled = true;
        scroll.enabled = true;
        input.enabled = true;

        words = {
          enabled = true;
          debounce = 200;
        };

        terminal.enabled = true;
        lazygit.enabled = true;
        gitbrowse.enabled = true;
        zen.enabled = true;
        scratch.enabled = true;
      };
    };

    # ── Gitsigns ─────────────────────────────────────────────────────────────
    plugins.gitsigns = {
      enable = true;
      settings = {
        current_line_blame = false;
        signs = {
          add.text = "▎";
          change.text = "▎";
          delete.text = "";
          topdelete.text = "";
          changedelete.text = "▎";
          untracked.text = "▎";
        };
        signs_staged_enable = true;
        signs_staged = {
          add.text = "▎";
          change.text = "▎";
          delete.text = "";
          topdelete.text = "";
          changedelete.text = "▎";
        };
      };
    };

    # ── Todo-comments ─────────────────────────────────────────────────────────
    plugins.todo-comments = {
      enable = true;
      settings.signs = true;
    };

    # ── Autopairs ────────────────────────────────────────────────────────────
    plugins.nvim-autopairs = {
      enable = true;
      settings.check_ts = true;
    };

    # ── Completion ───────────────────────────────────────────────────────────
    plugins.cmp = {
      enable = true;
      settings = {
        completion.completeopt = "menu,menuone,noinsert";
        window = {
          completion.border = "rounded";
          documentation.border = "rounded";
        };
        mapping = {
          "<C-n>" = "cmp.mapping.select_next_item()";
          "<C-p>" = "cmp.mapping.select_prev_item()";
          "<C-b>" = "cmp.mapping.scroll_docs(-4)";
          "<C-f>" = "cmp.mapping.scroll_docs(4)";
          "<C-Space>" = "cmp.mapping.complete()";
          "<C-e>" = "cmp.mapping.abort()";
          "<CR>" = "cmp.mapping.confirm({ select = true })";
        };
        sources = [
          { name = "nvim_lsp"; }
          { name = "luasnip"; }
          { name = "path"; }
          { name = "buffer"; }
        ];
      };
    };

    plugins.cmp-nvim-lsp.enable = true;
    plugins.cmp-buffer.enable = true;
    plugins.cmp-path.enable = true;
    plugins.cmp_luasnip.enable = true;

    # ── Snippets ─────────────────────────────────────────────────────────────
    plugins.luasnip = {
      enable = true;
      fromVscode = [ { } ];
    };

    plugins.friendly-snippets.enable = true;

    # ── Conform (formatação) ──────────────────────────────────────────────────
    plugins.conform-nvim = {
      enable = true;
      settings = {
        formatters_by_ft = {
          lua = [ "stylua" ];
          nix = [ "nixfmt" ];
          javascript = [ "prettier" ];
          typescript = [ "prettier" ];
          json = [ "prettier" ];
          yaml = [ "prettier" ];
          markdown = [ "prettier" ];
          html = [ "prettier" ];
          css = [ "prettier" ];
          sh = [ "shfmt" ];
        };
        formatters = {
          stylua.command = "${pkgs.stylua}/bin/stylua";
          nixfmt.command = "${pkgs.nixfmt}/bin/nixfmt";
          prettier.command = "${pkgs.prettier}/bin/prettier";
          shfmt.command = "${pkgs.shfmt}/bin/shfmt";
        };
      };
    };

    # ── LSP ──────────────────────────────────────────────────────────────────
    plugins.lsp = {
      enable = true;
      servers = {
        nixd = {
          enable = true;
          settings.nixd = {
            nixpkgs.expr = ''import (builtins.getFlake "/etc/nixos").inputs.nixpkgs { }'';
            formatting.command = [
              "nixfmt"
              "--stdin"
            ];
            options = {
              nixos.expr = ''(builtins.getFlake "/etc/nixos").nixosConfigurations.barbudus.options'';
              home_manager.expr = ''(builtins.getFlake "/etc/nixos").homeConfigurations."abutre@barbudus".options'';
            };
          };
        };

        nil_ls = {
          enable = true;
          settings.nil.formatting.command = [
            "nixfmt"
            "--stdin"
          ];
        };

        texlab = {
          enable = true;
          settings.texlab = {
            build = {
              executable = "latexmk";
              args = [
                "-pdf"
                "-interaction=nonstopmode"
                "-synctex=1"
                "%f"
              ];
              onSave = true;
            };
            forwardSearch = {
              executable = "zathura";
              args = [
                "--synctex-forward"
                "%l:1:%f"
                "%p"
              ];
            };
            chktex.onOpenAndSave = true;
          };
        };
      };
    };

    # gregorio-lsp: servidor custom não suportado pelo nixvim, configurado via extraConfigLua
    extraConfigLua = ''
      vim.diagnostic.config({
        virtual_text = {
          spacing = 4,
          source = "if_many",
          prefix = "●",
        },
        underline = true,
        update_in_insert = false,
        severity_sort = true,
        float = {
          border = "rounded",
          source = "always",
          header = "",
          prefix = "",
        },
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = " ",
            [vim.diagnostic.severity.WARN] = " ",
            [vim.diagnostic.severity.HINT] = "󰠠 ",
            [vim.diagnostic.severity.INFO] = " ",
          },
        },
      })

      vim.lsp.config["gregorio-lsp"] = {
        cmd = { "${pkgs.gregorio-lsp}/bin/gregorio-lsp" },
        filetypes = { "gabc", "nabc", "gregorio" },
      }
      vim.lsp.enable("gregorio-lsp")

      require("mini.icons").setup()
      require("mini.surround").setup({
        mappings = {
          add = "sa",
          delete = "sd",
          find = "sf",
          find_left = "sF",
          highlight = "sh",
          replace = "sr",
          update_n_lines = "sn",
        },
      })
      require("mini.ai").setup({
        n_lines = 500,
        custom_textobjects = {
          o = require("mini.ai").gen_spec.treesitter({
            a = { "@block.outer", "@conditional.outer", "@loop.outer" },
            i = { "@block.inner", "@conditional.inner", "@loop.inner" },
          }),
          f = require("mini.ai").gen_spec.treesitter({ a = "@function.outer", i = "@function.inner" }),
          c = require("mini.ai").gen_spec.treesitter({ a = "@class.outer", i = "@class.inner" }),
          t = { "<([%p%w]-)%f[^<%w][^<>]->.-</%1>", "^<.->().*()</[^/]->$" },
          d = { "%f[%d]%d+" },
          g = function()
            local from = { line = 1, col = 1 }
            local to = {
              line = vim.fn.line("$"),
              col = math.max(vim.fn.getline("$"):len(), 1),
            }
            return { from = from, to = to }
          end,
        },
      })

      require("lazydev").setup()

      require("luasnip.loaders.from_vscode").lazy_load()

      require("gregorio").setup()
    '';

    # ── Trouble ──────────────────────────────────────────────────────────────
    plugins.trouble.enable = true;

    # ── LazyDev (Lua LSP) ────────────────────────────────────────────────────
    plugins.lazydev.enable = true;

    # ── Plugins extras (sem módulo nixvim nativo) ─────────────────────────────
    extraPlugins = [
      pkgs.vimPlugins.vim-tmux-navigator
      pkgs.vimPlugins.persistence-nvim
      pkgs.vimPlugins.vimtex
      pkgs.vimPlugins.mini-nvim
      pkgs.gregorio-nvim
    ];

    extraPackages = with pkgs; [
      gregorio-lsp
      lazygit
      nixfmt
      prettier
      shfmt
      stylua
    ];
  };
}
