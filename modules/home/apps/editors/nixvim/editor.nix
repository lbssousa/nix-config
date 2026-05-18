# Camada editor do nixvim: busca, sintaxe, edição de texto.
# Equivalente aos plugins de edição do LazyVim (editor.lua, coding.lua).
{ pkgs, ... }:

{
  programs.nixvim = {
    plugins = {
      # Syntax highlighting e parsing de estrutura do código
      treesitter = {
        enable = true;
        settings = {
          indent.enable = true;
          highlight.enable = true;
          incremental_selection = {
            enable = true;
            keymaps = {
              init_selection = "<C-space>";
              node_incremental = "<C-space>";
              scope_incremental = false;
              node_decremental = "<bs>";
            };
          };
        };
        grammarPackages = with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [
          bash
          c
          css
          diff
          html
          javascript
          json
          json5
          lua
          luadoc
          make
          markdown
          markdown_inline
          nix
          python
          query
          regex
          rust
          toml
          typescript
          vimdoc
          xml
          yaml
        ];
      };

      # Objetos de texto baseados em treesitter
      treesitter-textobjects = {
        enable = true;
        select = {
          enable = true;
          lookahead = true;
          keymaps = {
            "af" = {
              query = "@function.outer";
              desc = "ao redor da função";
            };
            "if" = {
              query = "@function.inner";
              desc = "dentro da função";
            };
            "ac" = {
              query = "@class.outer";
              desc = "ao redor da classe";
            };
            "ic" = {
              query = "@class.inner";
              desc = "dentro da classe";
            };
            "aa" = {
              query = "@parameter.outer";
              desc = "ao redor do argumento";
            };
            "ia" = {
              query = "@parameter.inner";
              desc = "dentro do argumento";
            };
          };
        };
        move = {
          enable = true;
          gotoNextStart = {
            "]f" = {
              query = "@function.outer";
              desc = "Próxima função";
            };
            "]c" = {
              query = "@class.outer";
              desc = "Próxima classe";
            };
          };
          gotoPreviousStart = {
            "[f" = {
              query = "@function.outer";
              desc = "Função anterior";
            };
            "[c" = {
              query = "@class.outer";
              desc = "Classe anterior";
            };
          };
        };
      };

      # Busca fuzzy
      telescope = {
        enable = true;
        settings = {
          defaults = {
            prompt_prefix = " ";
            selection_caret = " ";
            file_ignore_patterns = [
              "node_modules"
              ".git/"
              "target/"
            ];
          };
        };
        extensions.fzf-native.enable = true;
        keymaps = {
          "<leader>ff" = {
            action = "find_files";
            options.desc = "Buscar arquivos";
          };
          "<leader>fg" = {
            action = "live_grep";
            options.desc = "Buscar texto (grep)";
          };
          "<leader>fb" = {
            action = "buffers";
            options.desc = "Buscar buffers";
          };
          "<leader>fh" = {
            action = "help_tags";
            options.desc = "Buscar ajuda";
          };
          "<leader>fr" = {
            action = "oldfiles";
            options.desc = "Arquivos recentes";
          };
          "<leader>fc" = {
            action = "commands";
            options.desc = "Buscar comandos";
          };
          "<leader>sk" = {
            action = "keymaps";
            options.desc = "Buscar keymaps";
          };
          "<leader>sd" = {
            action = "diagnostics";
            options.desc = "Buscar diagnósticos";
          };
          "<leader>sw" = {
            action = "grep_string";
            options.desc = "Buscar palavra sob cursor";
          };
          "gr" = {
            action = "lsp_references";
            options.desc = "Referências LSP";
          };
          "gi" = {
            action = "lsp_implementations";
            options.desc = "Implementações LSP";
          };
          "<leader>ss" = {
            action = "lsp_document_symbols";
            options.desc = "Símbolos do documento";
          };
          "<leader>sS" = {
            action = "lsp_workspace_symbols";
            options.desc = "Símbolos do workspace";
          };
        };
      };

      # Pares de delimitadores automáticos
      nvim-autopairs = {
        enable = true;
        settings.check_ts = true;
      };

      # Comentários
      comment.enable = true;

      # Operações em pares (surround)
      surround.enable = true;

      # Marcação de TODO, FIXME, NOTE etc.
      todo-comments = {
        enable = true;
        settings.signs = true;
      };

      # Pulos rápidos pelo texto
      flash = {
        enable = true;
        settings.modes = {
          search.enabled = false;
          char = {
            jump_labels = true;
          };
        };
      };

      # Pré-visualização de linhas na busca
      nvim-spectre.enable = true;

      # Gerenciador de sessões
      persistence = {
        enable = true;
        settings.dir.__raw = ''vim.fn.stdpath("state") .. "/sessions/"'';
      };

      # Histórico de desfazer visual
      undotree = {
        enable = true;
        settings.FocusOnToggle = true;
      };
    };

    keymaps = [
      # Flash
      {
        key = "s";
        action.__raw = ''function() require("flash").jump() end'';
        mode = [
          "n"
          "x"
          "o"
        ];
        options.desc = "Flash: pular";
      }
      {
        key = "S";
        action.__raw = ''function() require("flash").treesitter() end'';
        mode = [
          "n"
          "x"
          "o"
        ];
        options.desc = "Flash: treesitter";
      }
      # Histórico de desfazer
      {
        key = "<leader>uu";
        action = "<cmd>UndotreeToggle<CR>";
        mode = "n";
        options.desc = "Histórico de desfazer";
      }
      # Sessão
      {
        key = "<leader>qs";
        action.__raw = ''function() require("persistence").load() end'';
        mode = "n";
        options.desc = "Restaurar sessão";
      }
      {
        key = "<leader>ql";
        action.__raw = ''function() require("persistence").load({ last = true }) end'';
        mode = "n";
        options.desc = "Restaurar última sessão";
      }
    ];
  };
}
