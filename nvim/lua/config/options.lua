-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Leader = `\` (backslash), matching the old NvChad config (ubuntu-2026).
-- This MUST be set here: config/options.lua is loaded before lazy.nvim resolves
-- plugin `keys` specs, so every LazyVim and custom mapping picks up `\` as <leader>.
-- localleader was the Vim default `\` in the old config too, so both stay `\`.
vim.g.mapleader = "\\"
vim.g.maplocalleader = "\\"
