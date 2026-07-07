-- Additional options / overrides of LazyVim's default options.
-- LazyVim already sets most sensible options; here we only adjust what
-- differs from the default.

local opt = vim.opt

-- Marks the column limit (vertical line at 80 characters)
opt.colorcolumn = "80"

-- Keep more lines visible while scrolling
opt.scrolloff = 8
opt.sidescrolloff = 8
