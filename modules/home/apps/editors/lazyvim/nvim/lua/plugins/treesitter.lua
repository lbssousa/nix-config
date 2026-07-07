-- Treesitter: adds the Gregorio grammar to the set of maintained parsers.
-- The gregorio.so parser is already on the rtp via Nix's
-- programs.neovim.plugins; here we just make sure nvim-treesitter recognizes it.
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
