-- gregorio.nvim plugin for GABC/NABC (Gregorian notation) support.
-- Loaded directly from the Nix store (not GitHub) via dir = paths.gregorio_nvim.
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
