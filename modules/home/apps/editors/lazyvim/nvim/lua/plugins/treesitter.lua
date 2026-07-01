-- Treesitter: adiciona a gramática Gregorio ao conjunto de parsers mantidos.
-- O parser gregorio.so já está no rtp via programs.neovim.plugins do Nix;
-- aqui apenas garantimos que o nvim-treesitter o reconhece.
return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "bash",
        "css",
        "html",
        "javascript",
        "json",
        "lua",
        "luadoc",
        "markdown",
        "markdown_inline",
        "nix",
        "python",
        "regex",
        "rust",
        "toml",
        "tsx",
        "typescript",
        "vim",
        "vimdoc",
        "xml",
        "yaml",
      },
    },
  },
}
