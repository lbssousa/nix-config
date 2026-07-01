-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Falha ao clonar lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPressione qualquer tecla para sair...", "ErrorMsg" },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    -- LazyVim e todos os seus padrões
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },

    -- Extras do LazyVim
    { import = "lazyvim.plugins.extras.lang.nix" },
    { import = "lazyvim.plugins.extras.lang.rust" },
    { import = "lazyvim.plugins.extras.lang.tex" },

    -- Overrides e plugins locais
    { import = "plugins" },
  },
  defaults = {
    lazy = false,
    version = false, -- sempre usa o commit mais recente
  },
  install = { colorscheme = { "tokyonight", "habamax" } },
  checker = { enabled = true }, -- verifica atualizações automaticamente
  performance = {
    rtp = {
      -- Desabilita plugins padrão do neovim que o LazyVim já substitui
      disabled_plugins = {
        "gzip",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})
