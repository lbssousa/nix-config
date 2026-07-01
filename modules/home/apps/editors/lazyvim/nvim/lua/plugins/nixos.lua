-- Adaptações para o ambiente NixOS / Nix.
-- Mason não funciona no Nix porque os binários que instala requerem um FHS
-- tradicional. Desabilitamos Mason e todas as suas extensões; as ferramentas
-- chegam ao PATH via home.packages no Nix.
return {
  { "williamboman/mason.nvim", enabled = false },
  { "williamboman/mason-lspconfig.nvim", enabled = false },
  { "jay-babu/mason-nvim-dap.nvim", enabled = false },
}
