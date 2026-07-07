-- LaTeX: uses zathura as the viewer and latexmk as the compiler.
-- LazyVim's lang.tex extra already enables vimtex + texlab; here we only
-- override the environment-specific settings.
return {
  {
    "lervag/vimtex",
    opts = {},
    config = function()
      -- Use zathura with SyncTeX support
      vim.g.vimtex_view_method = "zathura"
      -- Default compiler
      vim.g.vimtex_compiler_method = "latexmk"
      -- Map <leader>l* to vimtex commands (LazyVim uses <leader>l for LSP,
      -- so we remap to <leader>v for "vimtex")
      vim.g.vimtex_mappings_prefix = "<localleader>"
    end,
  },
}
