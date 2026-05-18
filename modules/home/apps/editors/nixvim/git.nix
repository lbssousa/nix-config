# Camada git do nixvim: indicadores de alterações, integração lazygit e diff.
# Equivalente ao git.lua do LazyVim.
{ pkgs, ... }:

{
  programs.nixvim = {
    plugins = {
      # Indicadores de alterações na calha (gutter)
      gitsigns = {
        enable = true;
        settings = {
          signs = {
            add.text = "▎";
            change.text = "▎";
            delete.text = "";
            topdelete.text = "";
            changedelete.text = "▎";
            untracked.text = "▎";
          };
          current_line_blame = false;
          current_line_blame_opts.delay = 1000;
          on_attach.__raw = ''
            function(buffer)
              local gs = package.loaded.gitsigns

              local function map(mode, l, r, desc)
                vim.keymap.set(mode, l, r, { buffer = buffer, desc = desc })
              end

              -- Navegar entre hunks
              map("n", "]h", function()
                if vim.wo.diff then
                  vim.cmd.normal({ "]c", bang = true })
                else
                  gs.nav_hunk("next")
                end
              end, "Próximo hunk")

              map("n", "[h", function()
                if vim.wo.diff then
                  vim.cmd.normal({ "[c", bang = true })
                else
                  gs.nav_hunk("prev")
                end
              end, "Hunk anterior")

              -- Ações
              map("n", "<leader>ghp", gs.preview_hunk, "Pré-visualizar hunk")
              map("n", "<leader>ghs", gs.stage_hunk, "Preparar hunk")
              map("n", "<leader>ghr", gs.reset_hunk, "Restaurar hunk")
              map("v", "<leader>ghs", function()
                gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
              end, "Preparar hunk (seleção)")
              map("v", "<leader>ghr", function()
                gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
              end, "Restaurar hunk (seleção)")
              map("n", "<leader>ghS", gs.stage_buffer, "Preparar buffer")
              map("n", "<leader>ghu", gs.undo_stage_hunk, "Desfazer preparação")
              map("n", "<leader>ghR", gs.reset_buffer, "Restaurar buffer")
              map("n", "<leader>ghd", gs.diffthis, "Diff do arquivo")
              map("n", "<leader>ghD", function() gs.diffthis("~") end, "Diff do arquivo (HEAD)")
              map("n", "<leader>gb", gs.toggle_current_line_blame, "Blame da linha")
            end
          '';
        };
      };

      # Integração com lazygit (via terminal flutuante)
      lazygit = {
        enable = true;
        package = pkgs.lazygit;
      };

      # Visualizador de diff/merge
      diffview = {
        enable = true;
        settings.enhanced_diff_hl = true;
      };
    };

    keymaps = [
      # LazyGit
      {
        key = "<leader>gg";
        action = "<cmd>LazyGit<CR>";
        mode = "n";
        options.desc = "LazyGit";
      }
      {
        key = "<leader>gf";
        action = "<cmd>LazyGitCurrentFile<CR>";
        mode = "n";
        options.desc = "LazyGit (arquivo atual)";
      }
      # Diffview
      {
        key = "<leader>gd";
        action = "<cmd>DiffviewOpen<CR>";
        mode = "n";
        options.desc = "Abrir diffview";
      }
      {
        key = "<leader>gD";
        action = "<cmd>DiffviewClose<CR>";
        mode = "n";
        options.desc = "Fechar diffview";
      }
      {
        key = "<leader>gh";
        action = "<cmd>DiffviewFileHistory %<CR>";
        mode = "n";
        options.desc = "Histórico do arquivo";
      }
    ];
  };
}
