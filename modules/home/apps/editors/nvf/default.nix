{ pkgs, lib, ... }:

{
  programs.neovim.enable = lib.mkForce false;

  home.packages = with pkgs; [
    lazygit # TUI git (integrado ao Snacks e útil no shell)
    gcc # compatibilidade com plugins/gramáticas que ainda compilam artefatos locais
    stylua
    prettier
    shfmt
    nixfmt
    wl-clipboard # wl-copy/wl-paste: provider de clipboard do neovim no Wayland
  ];

  programs.nvf = {
    enable = true;
    defaultEditor = true;

    settings = {
      vim = {
        viAlias = true;
        vimAlias = true;
        vendoredKeymaps.enable = false;

        lazy.enable = true;

        globals = {
          mapleader = " ";
          maplocalleader = "\\";
          autoformat = true;
          vimtex_view_method = "zathura";
          vimtex_compiler_method = "latexmk";
          vimtex_mappings_prefix = "\\";
        };

        startPlugins = [
          "tokyonight"
          "friendly-snippets"
          "mini-ai"
          "mini-icons"
          "mini-surround"
        ];

        extraPackages = with pkgs; [
          gregorio-lsp
          lazygit
          nixfmt
          prettier
          shfmt
          stylua
        ];

        extraPlugins = {
          vim-tmux-navigator.package = pkgs.vimPlugins.vim-tmux-navigator;

          persistence.package = pkgs.vimPlugins.persistence-nvim;

          vimtex.package = pkgs.vimPlugins.vimtex;

          gregorio = {
            package = pkgs.gregorio-nvim;
            setup = ''
              require("gregorio").setup()
            '';
          };
        };

        pluginRC = {
          theme = ''
            require("tokyonight").setup({
              style = "moon",
              transparent = false,
              terminal_colors = true,
            })
            vim.cmd.colorscheme("tokyonight")
          '';

          mini = ''
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
            require("luasnip.loaders.from_vscode").lazy_load()
          '';
        };

        luaConfigRC = {
          core = ''
            local opt = vim.opt

            opt.number = true
            opt.relativenumber = true
            opt.expandtab = true
            opt.tabstop = 2
            opt.shiftwidth = 2
            opt.smartindent = true
            opt.termguicolors = true
            opt.clipboard = "unnamedplus"
            opt.colorcolumn = "80"
            opt.scrolloff = 8
            opt.sidescrolloff = 8
            opt.cursorline = true
            opt.signcolumn = "yes"
            opt.wrap = true
            opt.linebreak = true
            opt.breakindent = true
            opt.textwidth = 80
            opt.ignorecase = true
            opt.smartcase = true
            opt.splitbelow = true
            opt.splitright = true
            opt.undofile = true
            opt.undolevels = 10000
            opt.timeoutlen = 300
            opt.updatetime = 200
            opt.autowrite = true
            opt.conceallevel = 2
            opt.confirm = true
            opt.foldlevel = 99
            opt.foldmethod = "indent"
            opt.foldtext = ""
            opt.inccommand = "nosplit"
            opt.list = true
            opt.pumblend = 10
            opt.pumheight = 10
            opt.ruler = false
            opt.shiftround = true
            opt.showmode = false
            opt.smoothscroll = true
            opt.splitkeep = "screen"
            opt.virtualedit = "block"
            opt.winminwidth = 5
            opt.fillchars = {
              eob = " ",
              foldopen = "▾",
              foldclose = "▸",
              fold = " ",
              foldsep = " ",
            }
            opt.listchars = {
              tab = "» ",
              trail = "·",
              nbsp = "␣",
            }

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
          '';

          autocmds = ''
            local augroup = vim.api.nvim_create_augroup("abutre_nvf", { clear = true })

            vim.api.nvim_create_autocmd("TextYankPost", {
              group = augroup,
              desc = "Realçar texto ao copiar",
              callback = function()
                vim.highlight.on_yank()
              end,
            })

            vim.api.nvim_create_autocmd("CursorHold", {
              group = augroup,
              desc = "Exibir diagnóstico sob o cursor",
              callback = function()
                vim.diagnostic.open_float(nil, {
                  focusable = false,
                  close_events = { "BufLeave", "CursorMoved", "InsertEnter", "FocusLost" },
                  border = "rounded",
                  source = "always",
                  prefix = " ",
                  scope = "cursor",
                })
              end,
            })

            vim.api.nvim_create_autocmd("FileType", {
              group = augroup,
              pattern = { "help", "man" },
              desc = "Abrir help/man em janela vertical",
              callback = function()
                vim.cmd("wincmd L")
              end,
            })

            vim.api.nvim_create_autocmd({ "FocusGained", "TermClose", "TermLeave" }, {
              group = augroup,
              desc = "Recarregar arquivo modificado externamente",
              callback = function()
                if vim.o.buftype ~= "nofile" then
                  vim.cmd("checktime")
                end
              end,
            })

            vim.api.nvim_create_autocmd("VimResized", {
              group = augroup,
              desc = "Equalizar janelas ao redimensionar",
              callback = function()
                local tab = vim.fn.tabpagenr()
                vim.cmd("tabdo wincmd =")
                vim.cmd("tabnext " .. tab)
              end,
            })

            vim.api.nvim_create_autocmd("BufReadPost", {
              group = augroup,
              desc = "Restaurar última posição do cursor",
              callback = function(ev)
                if vim.tbl_contains({ "gitcommit" }, vim.bo[ev.buf].filetype) then
                  return
                end
                local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
                local lcount = vim.api.nvim_buf_line_count(ev.buf)
                if mark[1] > 0 and mark[1] <= lcount then
                  pcall(vim.api.nvim_win_set_cursor, 0, mark)
                end
              end,
            })

            vim.api.nvim_create_autocmd("FileType", {
              group = augroup,
              pattern = {
                "help",
                "man",
                "qf",
                "notify",
                "checkhealth",
                "lspinfo",
                "startuptime",
                "grug-far",
              },
              desc = "Fechar com q em filetypes utilitários",
              callback = function(ev)
                vim.bo[ev.buf].buflisted = false
                vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = ev.buf, silent = true })
              end,
            })

            vim.api.nvim_create_autocmd("FileType", {
              group = augroup,
              pattern = { "text", "plaintex", "gitcommit", "markdown" },
              desc = "Wrap e spell em filetypes de texto",
              callback = function()
                vim.opt_local.wrap = true
                vim.opt_local.spell = true
              end,
            })

            vim.api.nvim_create_autocmd("FileType", {
              group = augroup,
              pattern = { "json", "jsonc", "json5" },
              desc = "Desabilitar conceallevel para JSON",
              callback = function()
                vim.opt_local.conceallevel = 0
              end,
            })

            vim.api.nvim_create_autocmd("BufWritePre", {
              group = augroup,
              desc = "Criar diretórios intermediários ao salvar",
              callback = function(ev)
                if ev.match:match("^%w%w+:[\\/][\\/]") then
                  return
                end
                local file = vim.uv.fs_realpath(ev.match) or ev.match
                vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
              end,
            })

            vim.api.nvim_create_autocmd("BufWritePre", {
              group = augroup,
              desc = "Formatar ao salvar quando autoformat estiver ativo",
              callback = function(ev)
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
              end,
            })

            vim.api.nvim_create_autocmd("LspAttach", {
              group = augroup,
              desc = "Keymaps extras para gregorio-lsp",
              callback = function(args)
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
              end,
            })
          '';

          keymaps = ''
            local map = vim.keymap.set

            local function opts(desc)
              return { silent = true, desc = desc }
            end

            -- Navegação entre janelas neovim e painéis tmux (vim-tmux-navigator)
            map("n", "<C-h>", "<Cmd>TmuxNavigateLeft<CR>", opts("Painel/janela esquerda"))
            map("n", "<C-j>", "<Cmd>TmuxNavigateDown<CR>", opts("Painel/janela abaixo"))
            map("n", "<C-k>", "<Cmd>TmuxNavigateUp<CR>", opts("Painel/janela acima"))
            map("n", "<C-l>", "<Cmd>TmuxNavigateRight<CR>", opts("Painel/janela direita"))
            map("n", "<C-\\>", "<Cmd>TmuxNavigatePrevious<CR>", opts("Painel/janela anterior"))

            map("n", "<C-Up>", "<cmd>resize +2<CR>", opts("Aumentar janela"))
            map("n", "<C-Down>", "<cmd>resize -2<CR>", opts("Diminuir janela"))
            map("n", "<C-Left>", "<cmd>vertical resize -2<CR>", opts("Diminuir janela (h)"))
            map("n", "<C-Right>", "<cmd>vertical resize +2<CR>", opts("Aumentar janela (h)"))

            map("v", "<", "<gv", opts("Recuar"))
            map("v", ">", ">gv", opts("Avançar"))

            map("n", "<A-j>", "<cmd>m .+1<CR>==", opts("Mover linha ↓"))
            map("n", "<A-k>", "<cmd>m .-2<CR>==", opts("Mover linha ↑"))
            map("v", "<A-j>", ":m '>+1<CR>gv=gv", opts("Mover seleção ↓"))
            map("v", "<A-k>", ":m '<-2<CR>gv=gv", opts("Mover seleção ↑"))

            map("n", "<Esc>", "<cmd>nohlsearch<CR>")
            map({ "n", "i", "v" }, "<C-s>", "<cmd>w<CR><Esc>", opts("Salvar"))
            map("n", "<leader>qq", "<cmd>qa<CR>", opts("Sair (todo)"))
            map("n", "<leader>fn", "<cmd>enew<CR>", opts("Novo arquivo"))

            map("n", "<S-h>", "<cmd>bprevious<CR>", opts("Buffer anterior"))
            map("n", "<S-l>", "<cmd>bnext<CR>", opts("Próximo buffer"))
            map("n", "<leader>bd", "<cmd>bdelete<CR>", opts("Fechar buffer"))
            map("n", "<leader>bo", "<cmd>%bdelete|edit#|bdelete#<CR>", opts("Fechar outros buffers"))

            map({ "n", "x" }, "j", function()
              return vim.v.count == 0 and "gj" or "j"
            end, { expr = true, silent = true, desc = "↓ (linha visual)" })
            map({ "n", "x" }, "k", function()
              return vim.v.count == 0 and "gk" or "k"
            end, { expr = true, silent = true, desc = "↑ (linha visual)" })

            map("n", "<leader>ur", "<cmd>nohlsearch<bar>diffupdate<bar>normal! <C-l><CR>", opts("Redesenhar / limpar busca"))

            map({ "n", "x", "o" }, "n", function()
              return vim.v.searchforward == 1 and "nzv" or "Nzv"
            end, { expr = true, silent = true, desc = "Próx. resultado da busca" })
            map({ "n", "x", "o" }, "N", function()
              return vim.v.searchforward == 1 and "Nzv" or "nzv"
            end, { expr = true, silent = true, desc = "Result. anterior da busca" })

            map("n", "]e", function()
              vim.diagnostic.goto_next({ severity = vim.diagnostic.severity.ERROR })
            end, opts("Próximo erro"))
            map("n", "[e", function()
              vim.diagnostic.goto_prev({ severity = vim.diagnostic.severity.ERROR })
            end, opts("Erro anterior"))
            map("n", "]w", function()
              vim.diagnostic.goto_next({ severity = vim.diagnostic.severity.WARN })
            end, opts("Próximo warning"))
            map("n", "[w", function()
              vim.diagnostic.goto_prev({ severity = vim.diagnostic.severity.WARN })
            end, opts("Warning anterior"))

            map("n", "]q", "<cmd>cnext<CR>", opts("Próximo quickfix"))
            map("n", "[q", "<cmd>cprev<CR>", opts("Quickfix anterior"))
            map("n", "]Q", "<cmd>clast<CR>", opts("Último quickfix"))
            map("n", "[Q", "<cmd>cfirst<CR>", opts("Primeiro quickfix"))

            map("n", "<leader>-", "<cmd>split<CR>", opts("Dividir janela (horizontal)"))
            map("n", "<leader>|", "<cmd>vsplit<CR>", opts("Dividir janela (vertical)"))
            map("n", "<leader>wd", "<cmd>close<CR>", opts("Fechar janela"))

            map("n", "<leader>bb", "<cmd>e #<CR>", opts("Alternar buffer"))
            map("n", "<leader>bD", "<cmd>bd<CR>", opts("Fechar buffer e janela"))

            map("n", "<leader><tab><tab>", "<cmd>tabnew<CR>", opts("Nova aba"))
            map("n", "<leader><tab>d", "<cmd>tabclose<CR>", opts("Fechar aba"))
            map("n", "<leader><tab>]", "<cmd>tabnext<CR>", opts("Próxima aba"))
            map("n", "<leader><tab>[", "<cmd>tabprevious<CR>", opts("Aba anterior"))
            map("n", "<leader><tab>f", "<cmd>tabfirst<CR>", opts("Primeira aba"))
            map("n", "<leader><tab>l", "<cmd>tablast<CR>", opts("Última aba"))

            map("n", "<leader>e", "<cmd>Neotree toggle<CR>", opts("Explorador de arquivos"))
            map("n", "<leader>E", "<cmd>Neotree focus<CR>", opts("Focar explorador"))

            map("n", "<leader>bp", "<cmd>BufferLineTogglePin<CR>", opts("Fixar buffer"))
            map("n", "<leader>bP", "<cmd>BufferLineGroupClose ungrouped<CR>", opts("Fechar buffers não fixados"))
            map("n", "<leader>br", "<cmd>BufferLineCloseRight<CR>", opts("Fechar buffers à direita"))
            map("n", "<leader>bl", "<cmd>BufferLineCloseLeft<CR>", opts("Fechar buffers à esquerda"))
            map("n", "]B", "<cmd>BufferLineMoveNext<CR>", opts("Mover buffer para direita"))
            map("n", "[B", "<cmd>BufferLineMovePrev<CR>", opts("Mover buffer para esquerda"))
            map("n", "<leader>bj", "<cmd>BufferLinePick<CR>", opts("Selecionar buffer"))

            map({ "n", "x", "o" }, "s", function()
              require("flash").jump()
            end, opts("Flash"))
            map({ "n", "x", "o" }, "S", function()
              require("flash").treesitter()
            end, opts("Flash Treesitter"))
            map("o", "r", function()
              require("flash").remote()
            end, opts("Flash Remote"))
            map({ "o", "x" }, "R", function()
              require("flash").treesitter_search()
            end, opts("Flash Treesitter Search"))
            map("c", "<C-s>", function()
              require("flash").toggle()
            end, opts("Flash: alternar em busca"))

            map("n", "]t", function()
              require("todo-comments").jump_next()
            end, opts("Próximo TODO"))
            map("n", "[t", function()
              require("todo-comments").jump_prev()
            end, opts("TODO anterior"))
            map("n", "<leader>st", "<cmd>TodoTelescope keywords=TODO,FIXME<CR>", opts("Buscar TODO/FIXME"))
            map("n", "<leader>sT", "<cmd>TodoTelescope<CR>", opts("Buscar todos os TODOs"))

            map("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<CR>", opts("Diagnósticos"))
            map("n", "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<CR>", opts("Diagnósticos (buffer)"))
            map("n", "<leader>xL", "<cmd>Trouble loclist toggle<CR>", opts("Lista de localização"))
            map("n", "<leader>xQ", "<cmd>Trouble qflist toggle<CR>", opts("Quickfix"))
            map("n", "<leader>xt", "<cmd>TodoTrouble keywords=TODO,FIXME<CR>", opts("TODO/FIXME (Trouble)"))
            map("n", "<leader>xT", "<cmd>TodoTrouble<CR>", opts("Todos os TODOs (Trouble)"))
            map("n", "<leader>cs", "<cmd>Trouble symbols toggle<CR>", opts("Símbolos"))
            map("n", "<leader>cS", "<cmd>Trouble lsp toggle<CR>", opts("Referências/definições LSP"))

            map("n", "]h", "<cmd>Gitsigns next_hunk<CR>", opts("Próxima mudança"))
            map("n", "[h", "<cmd>Gitsigns prev_hunk<CR>", opts("Mudança anterior"))
            map("n", "<leader>ghs", "<cmd>Gitsigns stage_hunk<CR>", opts("Stage hunk"))
            map("n", "<leader>ghr", "<cmd>Gitsigns reset_hunk<CR>", opts("Reset hunk"))
            map("n", "<leader>ghp", "<cmd>Gitsigns preview_hunk<CR>", opts("Preview hunk"))
            map("n", "<leader>gb", "<cmd>Gitsigns blame_line<CR>", opts("Blame linha"))
            map("n", "]H", "<cmd>Gitsigns next_hunk<CR>", opts("Próxima mudança (staged)"))
            map("n", "[H", "<cmd>Gitsigns prev_hunk<CR>", opts("Mudança anterior (staged)"))
            map({ "n", "v" }, "<leader>ghS", "<cmd>Gitsigns stage_buffer<CR>", opts("Stage buffer"))
            map("n", "<leader>ghu", "<cmd>Gitsigns undo_stage_hunk<CR>", opts("Desfazer stage hunk"))
            map({ "n", "v" }, "<leader>ghR", "<cmd>Gitsigns reset_buffer<CR>", opts("Reset buffer"))
            map("n", "<leader>ghb", function()
              require("gitsigns").blame_line({ full = true })
            end, opts("Blame linha (completo)"))
            map("n", "<leader>ghB", "<cmd>Gitsigns blame<CR>", opts("Blame buffer"))
            map("n", "<leader>ghd", "<cmd>Gitsigns diffthis<CR>", opts("Diff (this)"))
            map("n", "<leader>ghD", function()
              require("gitsigns").diffthis("~")
            end, opts("Diff (último commit)"))
            map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", opts("Text-object hunk"))

            map({ "n", "v" }, "<leader>sr", "<cmd>GrugFar<CR>", opts("Buscar e substituir"))

            map("n", "<leader>qs", function()
              require("persistence").load()
            end, opts("Restaurar sessão"))
            map("n", "<leader>ql", function()
              require("persistence").load({ last = true })
            end, opts("Restaurar última sessão"))
            map("n", "<leader>qd", function()
              require("persistence").stop()
            end, opts("Não salvar sessão"))
            map("n", "<leader>qS", function()
              require("persistence").select()
            end, opts("Selecionar sessão"))

            map("n", "<leader>ff", "<cmd>Telescope find_files<CR>", opts("Arquivos"))
            map("n", "<leader>fg", "<cmd>Telescope live_grep<CR>", opts("Grep ao vivo"))
            map("n", "<leader>fb", "<cmd>Telescope buffers<CR>", opts("Buffers abertos"))
            map("n", "<leader>fh", "<cmd>Telescope help_tags<CR>", opts("Ajuda"))
            map("n", "<leader>fo", "<cmd>Telescope oldfiles<CR>", opts("Arquivos recentes"))
            map("n", "<leader>fc", "<cmd>Telescope commands<CR>", opts("Comandos"))
            map("n", "<leader>fr", "<cmd>Telescope resume<CR>", opts("Retomar busca"))
            map("n", "<leader>ss", "<cmd>Telescope lsp_document_symbols<CR>", opts("Símbolos (documento)"))
            map("n", "<leader>sS", "<cmd>Telescope lsp_workspace_symbols<CR>", opts("Símbolos (workspace)"))

            map("n", "<leader>n", function()
              Snacks.notifier.show_history()
            end, opts("Histórico de notificações"))
            map("n", "<leader>un", function()
              Snacks.notifier.hide()
            end, opts("Fechar notificações"))

            map("n", "<leader>ft", function()
              Snacks.terminal()
            end, opts("Terminal flutuante"))
            map({ "n", "t" }, "<C-/>", function()
              Snacks.terminal.toggle()
            end, opts("Terminal flutuante"))

            map("n", "<leader>gg", function()
              Snacks.lazygit()
            end, opts("LazyGit"))
            map("n", "<leader>gG", function()
              Snacks.lazygit({ cwd = vim.uv.cwd() })
            end, opts("LazyGit (diretório atual)"))
            map("n", "<leader>gf", function()
              Snacks.lazygit.log_file()
            end, opts("LazyGit (arquivo atual)"))
            map("n", "<leader>gl", function()
              Snacks.lazygit.log()
            end, opts("Log git"))

            map({ "n", "x" }, "<leader>gB", function()
              Snacks.gitbrowse()
            end, opts("Abrir no browser"))
            map({ "n", "x" }, "<leader>gY", function()
              Snacks.gitbrowse({
                open = function(url)
                  vim.fn.setreg("+", url)
                end,
                notify = false,
              })
            end, opts("Copiar URL git"))

            map("n", "<leader>.", function()
              Snacks.scratch()
            end, opts("Buffer temporário"))
            map("n", "<leader>S", function()
              Snacks.scratch.select()
            end, opts("Selecionar buffer temporário"))

            map("n", "gd", vim.lsp.buf.definition, opts("Ir para definição"))
            map("n", "gD", vim.lsp.buf.declaration, opts("Ir para declaração"))
            map("n", "gI", vim.lsp.buf.implementation, opts("Ir para implementação"))
            map("n", "gy", vim.lsp.buf.type_definition, opts("Ir para tipo"))
            map("n", "K", vim.lsp.buf.hover, opts("Hover"))
            map("n", "<leader>cr", vim.lsp.buf.rename, opts("Renomear símbolo"))
            map("n", "<leader>ca", vim.lsp.buf.code_action, opts("Ação de código"))
            map("n", "<leader>cd", vim.diagnostic.open_float, opts("Diagnóstico sob cursor"))
            map("n", "[d", vim.diagnostic.goto_prev, opts("Diagnóstico anterior"))
            map("n", "]d", vim.diagnostic.goto_next, opts("Próximo diagnóstico"))
            map("n", "gr", "<cmd>Telescope lsp_references<CR>", opts("Referências (Telescope)"))
            map("n", "<leader>cf", function()
              require("conform").format({ lsp_fallback = true })
            end, opts("Formatar arquivo"))
            map("v", "<leader>cf", function()
              require("conform").format({ lsp_fallback = true })
            end, opts("Formatar seleção"))
            map("n", "<leader>cR", function()
              local old_name = vim.fn.expand("%")
              vim.ui.input({ prompt = "Novo nome: ", default = old_name }, function(new_name)
                if not new_name or new_name == old_name then
                  return
                end
                vim.lsp.util.rename(old_name, new_name, {})
                vim.api.nvim_buf_set_name(0, new_name)
                vim.cmd("keepalt saveas! " .. new_name)
              end)
            end, opts("Renomear arquivo"))

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
        };

        theme.enable = false;

        treesitter = {
          enable = true;
          grammars = [ pkgs.tree-sitter-gregorio-nvim ];
          context.enable = true;
        };

        visuals.nvim-web-devicons.enable = true;

        statusline.lualine = {
          enable = true;
          setupOpts.options = {
            theme = "tokyonight";
            globalstatus = true;
            disabled_filetypes.statusline = [
              "dashboard"
              "alpha"
              "snacks_dashboard"
            ];
          };
        };

        tabline.nvimBufferline = {
          enable = true;
          setupOpts.options = {
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

        filetree.neo-tree = {
          enable = true;
          setupOpts = {
            close_if_last_window = true;
            popup_border_style = "rounded";
            window = {
              position = "left";
              width = 30;
            };
            default_component_configs.indent.with_expanders = true;
          };
        };

        binds.whichKey = {
          enable = true;
          setupOpts.preset = "helix";
          register = {
            "<leader>f" = "arquivo";
            "<leader>g" = "git";
            "<leader>gh" = "hunks git";
            "<leader>c" = "código";
            "<leader>b" = "buffer";
            "<leader>q" = "sair/sessão";
            "<leader>s" = "buscar";
            "<leader>u" = "ui";
            "<leader>w" = "janelas";
            "<leader>x" = "diagnósticos";
            "<leader><tab>" = "abas";
          };
        };

        ui.noice = {
          enable = true;
          setupOpts = {
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

        telescope.enable = true;

        utility = {
          motion.flash-nvim = {
            enable = true;
            setupOpts.modes.char.highlight.backdrop = false;
          };

          grug-far-nvim.enable = true;

          snacks-nvim = {
            enable = true;
            setupOpts = {
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
        };

        git = {
          enable = true;
          gitsigns = {
            enable = true;
            setupOpts = {
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
        };

        notes.todo-comments = {
          enable = true;
          setupOpts.signs = true;
        };

        autopairs.nvim-autopairs = {
          enable = true;
          setupOpts.check_ts = true;
        };

        autocomplete.nvim-cmp = {
          enable = true;
          sourcePlugins = [
            "cmp-buffer"
            "cmp-path"
            "cmp-luasnip"
            "cmp-nvim-lsp"
          ];
          mappings = {
            next = "<C-n>";
            previous = "<C-p>";
            scrollDocsUp = "<C-b>";
            scrollDocsDown = "<C-f>";
            complete = "<C-Space>";
            close = "<C-e>";
            confirm = "<CR>";
          };
          setupOpts = {
            completion.completeopt = "menu,menuone,noinsert";
            window = {
              completion.border = "rounded";
              documentation.border = "rounded";
            };
          };
          sources = {
            nvim_lsp = "[LSP]";
            luasnip = "[LuaSnip]";
            path = "[Path]";
            buffer = "[Buffer]";
          };
        };

        snippets.luasnip.enable = true;

        formatter.conform-nvim = {
          enable = true;
          setupOpts = {
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

        lsp = {
          enable = true;
          formatOnSave = false;
          lspkind.enable = false;
          lspsaga.enable = false;
          trouble.enable = true;
          lspSignature.enable = false;

          servers = {
            nixd.settings.nixd = {
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

            nil.settings.nil.formatting.command = [
              "nixfmt"
              "--stdin"
            ];

            texlab.settings.texlab = {
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

            "gregorio-lsp" = {
              cmd = [ "${pkgs.gregorio-lsp}/bin/gregorio-lsp" ];
              filetypes = [
                "gabc"
                "nabc"
                "gregorio"
              ];
            };
          };
        };

        languages = {
          enableFormat = false;
          enableTreesitter = true;
          enableExtraDiagnostics = false;

          lua = {
            enable = true;
            format.enable = false;
            extraDiagnostics.enable = false;
            lsp.lazydev.enable = true;
          };

          markdown = {
            enable = true;
            format.enable = false;
            extraDiagnostics.enable = false;
          };

          yaml.enable = true;

          bash = {
            enable = true;
            format.enable = false;
            extraDiagnostics.enable = false;
          };

          html = {
            enable = true;
            format.enable = false;
          };

          css = {
            enable = true;
            format.enable = false;
          };

          json = {
            enable = true;
            format.enable = false;
          };

          nix = {
            enable = true;
            lsp.servers = [
              "nixd"
              "nil"
            ];
            format.enable = false;
            extraDiagnostics = {
              enable = true;
              types = [
                "statix"
                "deadnix"
              ];
            };
          };

          rust = {
            enable = true;
            format.enable = false;
            lsp.package = [ "rust-analyzer" ];
          };

          tex = {
            enable = true;
            format.enable = false;
          };
        };
      };
    };
  };
}
