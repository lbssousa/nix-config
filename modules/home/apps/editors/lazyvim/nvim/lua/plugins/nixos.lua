-- Adaptations for the NixOS / Nix environment.
-- Mason doesn't work on Nix because the binaries it installs require a
-- traditional FHS. We disable Mason and all its extensions; tools reach
-- PATH via home.packages in Nix.
return {
  { "williamboman/mason.nvim", enabled = false },
  { "williamboman/mason-lspconfig.nvim", enabled = false },
  { "jay-babu/mason-nvim-dap.nvim", enabled = false },
}
