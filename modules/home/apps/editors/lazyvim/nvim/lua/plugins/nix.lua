-- Overrides para Nix: nixd (LSP com awareness de flake e opções NixOS/HM)
-- e nil_ls (fallback leve). Paths injetados via nix/paths.lua gerado pelo Nix.
local paths = require("nix.paths")

return {
  -- ── nixd: substituição da config padrão do extra lang.nix ─────────────
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        nixd = {
          mason = false,
          cmd = { paths.nixd },
          settings = {
            nixd = {
              nixpkgs = {
                -- Resolve nixpkgs do flake da configuração do sistema
                expr = 'import (builtins.getFlake "/etc/nixos").inputs.nixpkgs { }',
              },
              formatting = {
                command = { paths.nixfmt, "--stdin" },
              },
              options = {
                nixos = {
                  expr = '(builtins.getFlake "/etc/nixos").nixosConfigurations.barbudus.options',
                },
                home_manager = {
                  expr = '(builtins.getFlake "/etc/nixos").homeConfigurations."abutre@barbudus".options',
                },
              },
            },
          },
        },
        nil_ls = {
          mason = false,
          cmd = { paths.nil_ls },
        },
      },
    },
  },
  -- ── conform: usa nixfmt (RFC 166) para formatar arquivos Nix ──────────
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        nix = { paths.nixfmt },
      },
    },
  },
}
