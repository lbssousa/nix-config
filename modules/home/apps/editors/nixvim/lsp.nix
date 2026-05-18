# Camada LSP do nixvim: servidores de linguagem, completion e formatação.
# Equivalente ao lsp.lua e coding.lua do LazyVim.
{ pkgs, ... }:

{
  programs.nixvim = {
    plugins = {
      # Cliente LSP
      lsp = {
        enable = true;

        keymaps = {
          silent = true;
          lspBuf = {
            gd = {
              action = "definition";
              desc = "Ir para definição";
            };
            gD = {
              action = "declaration";
              desc = "Ir para declaração";
            };
            K = {
              action = "hover";
              desc = "Documentação hover";
            };
            "<leader>ca" = {
              action = "code_action";
              desc = "Ação de código";
            };
            "<leader>cr" = {
              action = "rename";
              desc = "Renomear símbolo";
            };
            "<leader>cf" = {
              action = "format";
              desc = "Formatar arquivo";
            };
          };
          diagnostic = {
            "[d" = {
              action = "goto_prev";
              desc = "Diagnóstico anterior";
            };
            "]d" = {
              action = "goto_next";
              desc = "Próximo diagnóstico";
            };
          };
        };

        servers = {
          # Nix
          nil_ls = {
            enable = true;
            package = pkgs.nil;
          };
          nixd = {
            enable = true;
            package = pkgs.nixd;
          };

          # Lua (para edição de configurações Lua em plugins)
          lua_ls = {
            enable = true;
            settings.Lua = {
              workspace.checkThirdParty = false;
              codeLens.enable = true;
              completion.callSnippet = "Replace";
            };
          };

          # Markdown
          marksman.enable = true;

          # YAML
          yamlls.enable = true;

          # Bash/Shell
          bashls.enable = true;

          # HTML/CSS/JSON
          html.enable = true;
          cssls.enable = true;
          jsonls.enable = true;
        };
      };

      # Completion (nvim-cmp)
      cmp = {
        enable = true;
        settings = {
          sources = [
            { name = "nvim_lsp"; }
            { name = "nvim_lsp_signature_help"; }
            { name = "luasnip"; }
            { name = "buffer"; }
            { name = "path"; }
          ];
          snippet.expand = ''
            function(args)
              require("luasnip").lsp_expand(args.body)
            end
          '';
          mapping = {
            "<CR>" = "cmp.mapping.confirm({ select = false })";
            "<C-Space>" = "cmp.mapping.complete()";
            "<C-j>" = "cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Insert })";
            "<C-k>" = "cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Insert })";
            "<C-d>" = "cmp.mapping.scroll_docs(4)";
            "<C-u>" = "cmp.mapping.scroll_docs(-4)";
            "<C-e>" = "cmp.mapping.abort()";
            "<Tab>" = ''
              cmp.mapping(function(fallback)
                if cmp.visible() then
                  cmp.select_next_item()
                elseif require("luasnip").expandable() then
                  require("luasnip").expand()
                elseif require("luasnip").expand_or_jumpable() then
                  require("luasnip").expand_or_jump()
                else
                  fallback()
                end
              end, { "i", "s" })
            '';
            "<S-Tab>" = ''
              cmp.mapping(function(fallback)
                if cmp.visible() then
                  cmp.select_prev_item()
                elseif require("luasnip").jumpable(-1) then
                  require("luasnip").jump(-1)
                else
                  fallback()
                end
              end, { "i", "s" })
            '';
          };
          experimental.ghost_text = true;
        };
      };

      # Snippets
      luasnip = {
        enable = true;
        settings.history = true;
      };
      friendly-snippets.enable = true;

      # Formatos de exibição para LSP
      lsp-format.enable = true;

      # Formatação via conform
      conform-nvim = {
        enable = true;
        settings = {
          format_on_save = {
            timeout_ms = 500;
            lsp_format = "fallback";
          };
          formatters_by_ft = {
            nix = [ "nixfmt" ];
            lua = [ "stylua" ];
            json = [ "prettier" ];
            yaml = [ "prettier" ];
            markdown = [ "prettier" ];
            sh = [ "shfmt" ];
          };
        };
      };

      # Diagnósticos visuais aprimorados
      trouble = {
        enable = true;
        settings = {
          use_diagnostic_signs = true;
          action_keys.close = "q";
        };
      };

      # Hints de assinaturas inline
      lsp-signature.enable = true;
    };

    keymaps = [
      # Trouble (lista de diagnósticos)
      {
        key = "<leader>xx";
        action = "<cmd>Trouble diagnostics toggle<CR>";
        mode = "n";
        options.desc = "Diagnósticos (Trouble)";
      }
      {
        key = "<leader>xX";
        action = "<cmd>Trouble diagnostics toggle filter.buf=0<CR>";
        mode = "n";
        options.desc = "Diagnósticos do buffer (Trouble)";
      }
      {
        key = "<leader>xL";
        action = "<cmd>Trouble loclist toggle<CR>";
        mode = "n";
        options.desc = "Location list (Trouble)";
      }
      {
        key = "<leader>xQ";
        action = "<cmd>Trouble qflist toggle<CR>";
        mode = "n";
        options.desc = "Quickfix list (Trouble)";
      }
      {
        key = "<leader>cs";
        action = "<cmd>Trouble symbols toggle focus=false<CR>";
        mode = "n";
        options.desc = "Símbolos (Trouble)";
      }
    ];
  };
}
