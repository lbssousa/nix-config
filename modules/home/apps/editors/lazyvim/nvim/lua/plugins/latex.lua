-- LaTeX: usa zathura como visualizador e latexmk como compilador.
-- O extra lang.tex do LazyVim já ativa vimtex + texlab; aqui só sobrescrevemos
-- as configurações específicas do ambiente.
return {
  {
    "lervag/vimtex",
    opts = {},
    config = function()
      -- Usa zathura com suporte a SyncTeX
      vim.g.vimtex_view_method = "zathura"
      -- Compilador padrão
      vim.g.vimtex_compiler_method = "latexmk"
      -- Mapeia <leader>l* para os comandos do vimtex (LazyVim usa <leader>l para LSP,
      -- então remapeamos para <leader>v de "vimtex")
      vim.g.vimtex_mappings_prefix = "<localleader>"
    end,
  },
}
