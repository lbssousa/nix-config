# Módulo Home Manager para LazyVim.
# "Instale com Nix, configure com Lua" — neovim e ferramentas vêm do Nix;
# plugins são gerenciados pelo lazy.nvim em runtime; a configuração fica
# nos arquivos Lua em ./nvim/.
#
# Uso: importe este arquivo no home.nix do usuário:
#   imports = [ ../../../modules/home/apps/editors/lazyvim ];
#
# Ao importar, o programs.neovim padrão do common.nix continua ativo, mas
# o init.lua do LazyVim (linkado via xdg.configFile) substitui o init.vim
# gerado pelo home-manager (neovim carrega init.lua com prioridade).
{ pkgs, ... }:

{
  programs.neovim = {
    # Pacotes que precisam estar no rtp mas não são gerenciados pelo lazy.nvim.
    # Neovim os carrega antes do init.lua via wrapper do home-manager.
    plugins = [
      # Gramática tree-sitter para Gregorio (GABC/NABC) pré-compilada pelo Nix.
      # nvim-treesitter encontra o parser em <rtp>/parser/gregorio.so.
      pkgs.tree-sitter-gregorio-nvim
    ];
  };

  # Ferramentas instaladas via Nix, disponíveis no PATH para o Neovim.
  home.packages = with pkgs; [
    # ── LSP servers ──────────────────────────────────────────────────────
    lua-language-server
    nil # nil_ls: Nix LSP leve e rápido
    nixd # nixd: Nix LSP com consciência de flake + opções NixOS/HM
    marksman # Markdown
    yaml-language-server
    bash-language-server
    vscode-langservers-extracted # html, css, json, eslint
    texlab # LaTeX
    rust-analyzer # Rust (complementa o rustup)
    # ── Formatadores e linters ───────────────────────────────────────────
    stylua # Lua
    prettier # JSON, YAML, Markdown, HTML, CSS
    shfmt # Shell
    nixfmt # Nix (RFC 166)
    # ── Ferramentas de suporte ───────────────────────────────────────────
    lazygit # TUI git (integrado ao LazyVim)
    gcc # compilador C para o nvim-treesitter compilar novas gramáticas
    # ── Gregorio ─────────────────────────────────────────────────────────
    gregorio-lsp
  ];

  # Configuração LazyVim: arquivos Lua linkados via xdg.configFile.
  # recursive = true: cada arquivo em ./nvim/ vira symlink individual em
  # ~/.config/nvim/; diretórios intermediários são criados como reais,
  # permitindo que o lazy.nvim grave lazy-lock.json no mesmo diretório.
  xdg.configFile."nvim" = {
    source = ./nvim;
    recursive = true;
  };

  # Caminhos da Nix store injetados como módulo Lua.
  # Acessível em qualquer spec do lazy.nvim via: local nix = require("nix.paths")
  xdg.configFile."nvim/lua/nix/paths.lua".text = ''
    -- Gerado pelo Nix — não editar manualmente.
    return {
      gregorio_nvim = "${pkgs.gregorio-nvim}",
      gregorio_lsp  = "${pkgs.gregorio-lsp}/bin/gregorio-lsp",
      nixfmt        = "${pkgs.nixfmt}/bin/nixfmt",
      nil_ls        = "${pkgs.nil}/bin/nil",
      nixd          = "${pkgs.nixd}/bin/nixd",
    }
  '';
}
