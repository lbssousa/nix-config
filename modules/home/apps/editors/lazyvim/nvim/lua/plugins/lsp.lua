-- LSP server configuration.
-- All servers have mason = false because they reach PATH via Nix.
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        lua_ls = { mason = false },
        marksman = { mason = false },
        yamlls = { mason = false },
        bashls = { mason = false },
        html = { mason = false },
        cssls = { mason = false },
        jsonls = { mason = false },
        texlab = {
          mason = false,
          settings = {
            texlab = {
              build = {
                executable = "latexmk",
                args = { "-pdf", "-interaction=nonstopmode", "-synctex=1", "%f" },
                onSave = true,
              },
              forwardSearch = {
                executable = "zathura",
                args = { "--synctex-forward", "%l:1:%f", "%p" },
              },
              chktex = { onOpenAndSave = true },
            },
          },
        },
      },
    },
  },
}
