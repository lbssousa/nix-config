-- Opções adicionais / overrides das opções padrão do LazyVim.
-- O LazyVim já define a maioria das opções sensatas; aqui só ajustamos o que
-- difere do padrão.

local opt = vim.opt

-- Indica o limite de coluna (linha vertical em 80 caracteres)
opt.colorcolumn = "80"

-- Mantém mais linhas visíveis ao rolar
opt.scrolloff = 8
opt.sidescrolloff = 8
