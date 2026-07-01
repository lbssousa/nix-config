-- Plugin gregorio.nvim para suporte ao GABC/NABC (notação gregoriana).
-- Carregado diretamente da Nix store (não do GitHub) via dir = paths.gregorio_nvim.
local paths = require("nix.paths")

return {
  {
    dir = paths.gregorio_nvim,
    name = "gregorio.nvim",
    lazy = false,
    config = function()
      require("gregorio").setup()
    end,
  },
}
