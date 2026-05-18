# Camada UI do nixvim: tema, statusline, árvore de arquivos, notificações.
# Equivalente aos plugins de UI do LazyVim.
_:

{
  programs.nixvim = {
    colorschemes.tokyonight = {
      enable = true;
      settings = {
        style = "night";
        transparent = false;
        terminal_colors = true;
        styles = {
          comments = {
            italic = true;
          };
          keywords = {
            italic = true;
          };
        };
      };
    };

    plugins = {
      # Ícones de arquivo para plugins de UI
      web-devicons.enable = true;

      # Statusline
      lualine = {
        enable = true;
        settings = {
          options = {
            theme = "tokyonight";
            globalstatus = true;
            disabled_filetypes = {
              statusline = [
                "dashboard"
                "alpha"
                "starter"
              ];
            };
          };
          sections = {
            lualine_a = [ "mode" ];
            lualine_b = [
              "branch"
              "diff"
              "diagnostics"
            ];
            lualine_c = [ "filename" ];
            lualine_x = [
              "encoding"
              "fileformat"
              "filetype"
            ];
            lualine_y = [ "progress" ];
            lualine_z = [ "location" ];
          };
        };
      };

      # Linha de buffers no topo
      bufferline = {
        enable = true;
        settings.options = {
          numbers = "none";
          close_command = "bdelete! %d";
          diagnostics = "nvim_lsp";
          separator_style = "slant";
          show_buffer_close_icons = true;
          show_close_icon = true;
          always_show_bufferline = false;
        };
      };

      # Árvore de arquivos
      neo-tree = {
        enable = true;
        closeIfLastWindow = true;
        window.width = 30;
      };

      # Guias de indentação
      indent-blankline = {
        enable = true;
        settings = {
          indent.char = "│";
          scope.enabled = true;
        };
      };

      # UI aprimorada para cmdline, mensagens e popupmenu
      noice = {
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
            lsp_doc_border = false;
          };
        };
      };

      # Notificações visuais
      notify = {
        enable = true;
        settings = {
          timeout = 3000;
          max_height.__raw = ''
            function()
              return math.floor(vim.o.lines * 0.75)
            end
          '';
          max_width.__raw = ''
            function()
              return math.floor(vim.o.columns * 0.75)
            end
          '';
          on_open.__raw = ''
            function(win)
              vim.api.nvim_win_set_config(win, { zindex = 100 })
            end
          '';
        };
      };

      # Dicas de atalhos de teclado
      which-key = {
        enable = true;
        settings = {
          delay = 300;
          spec = [
            {
              __unkeyed-1 = "<leader>b";
              group = "Buffers";
            }
            {
              __unkeyed-1 = "<leader>c";
              group = "Código";
            }
            {
              __unkeyed-1 = "<leader>f";
              group = "Arquivos";
            }
            {
              __unkeyed-1 = "<leader>g";
              group = "Git";
            }
            {
              __unkeyed-1 = "<leader>s";
              group = "Busca";
            }
            {
              __unkeyed-1 = "<leader>u";
              group = "UI";
            }
            {
              __unkeyed-1 = "<leader>x";
              group = "Diagnósticos";
            }
          ];
        };
      };

      # Tela inicial
      alpha = {
        enable = true;
        layout = "dashboard";
      };

      # Colunas coloridas para pares de delimitadores
      rainbow-delimiters.enable = true;
    };

    # Atalhos de UI
    keymaps = [
      {
        key = "<leader>e";
        action = "<cmd>Neotree toggle<CR>";
        mode = "n";
        options.desc = "Explorador de arquivos";
      }
      {
        key = "<leader>uf";
        action = "<cmd>Neotree focus<CR>";
        mode = "n";
        options.desc = "Focar explorador";
      }
    ];
  };
}
