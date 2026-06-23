-- Keymaps are automatically loaded on the VeryLazy event
-- Default LazyVim keymaps: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
--
-- Ported from the old NvChad v2.5 config (ubuntu-2026). Goal: keep the muscle
-- memory you had. Leader is `\` (set in config/options.lua). NvChad-only features
-- map onto LazyVim equivalents: NvimTree -> Snacks explorer, Telescope -> Snacks
-- picker, nvchad.term -> Snacks terminal, tabufline -> bufferline. Dropped (no
-- equivalent): NvChad theme picker (<leader>th) — theme is fixed Catppuccin.

local map = vim.keymap.set

-- ── your custom maps (the only non-default ones in the old config) ──────────
map("n", ";", ":", { desc = "CMD enter command mode" }) -- note: replaces ; repeat-find
map("i", "jk", "<ESC>", { desc = "escape insert" })
map("n", "<leader>q", "<cmd>qa!<CR>", { desc = "close all and exit" })
map("n", "<leader>gb", function() require("gitsigns").blame_line() end, { desc = "git blame line" })

-- ── insert-mode movement (NvChad emacs-style) ──────────────────────────────
map("i", "<C-b>", "<ESC>^i", { desc = "move beginning of line" })
map("i", "<C-e>", "<End>", { desc = "move end of line" }) -- note: blink uses <C-e> to hide its menu when open
map("i", "<C-h>", "<Left>", { desc = "move left" })
map("i", "<C-l>", "<Right>", { desc = "move right" })
map("i", "<C-j>", "<Down>", { desc = "move down" })
map("i", "<C-k>", "<Up>", { desc = "move up" })

-- ── general ─────────────────────────────────────────────────────────────────
map("n", "<Esc>", "<cmd>noh<CR>", { desc = "clear highlights" })
map("n", "<C-c>", "<cmd>%y+<CR>", { desc = "copy whole file" })
map("n", "<leader>n", "<cmd>set nu!<CR>", { desc = "toggle line number" })
map("n", "<leader>rn", "<cmd>set rnu!<CR>", { desc = "toggle relative number" })
map("n", "<leader>ds", vim.diagnostic.setloclist, { desc = "diagnostic loclist" })
map({ "n", "x" }, "<leader>fm", function() require("conform").format({ lsp_fallback = true }) end, { desc = "format file" })
-- NvCheatsheet has no LazyVim equivalent -> searchable keymap list instead
map("n", "<leader>ch", function() Snacks.picker.keymaps() end, { desc = "keymaps (cheatsheet)" })

-- ── buffers (NvChad tabufline -> bufferline / snacks) ───────────────────────
map("n", "<tab>", "<cmd>BufferLineCycleNext<CR>", { desc = "buffer next" }) -- note: shadows <C-i> jump-forward
map("n", "<S-tab>", "<cmd>BufferLineCyclePrev<CR>", { desc = "buffer prev" })
map("n", "<leader>b", "<cmd>enew<CR>", { desc = "new buffer" }) -- shadows LazyVim <leader>b group (still reachable after timeout)
map("n", "<leader>x", function() Snacks.bufdelete() end, { desc = "close buffer" }) -- shadows <leader>x trouble group (timeout)

-- ── comment ─────────────────────────────────────────────────────────────────
map("n", "<leader>/", "gcc", { desc = "toggle comment", remap = true })
map("v", "<leader>/", "gc", { desc = "toggle comment", remap = true })

-- ── file explorer (NvimTree -> Snacks explorer) ─────────────────────────────
map("n", "<C-n>", function() Snacks.explorer() end, { desc = "explorer toggle" })

-- ── picker (Telescope -> Snacks picker) ─────────────────────────────────────
map("n", "<leader>ff", function() Snacks.picker.files() end, { desc = "find files" })
map("n", "<leader>fa", function() Snacks.picker.files({ hidden = true, ignored = true }) end, { desc = "find all files" })
map("n", "<leader>fw", function() Snacks.picker.grep() end, { desc = "live grep" })
map("n", "<leader>fb", function() Snacks.picker.buffers() end, { desc = "find buffers" })
map("n", "<leader>fh", function() Snacks.picker.help() end, { desc = "help pages" })
map("n", "<leader>fo", function() Snacks.picker.recent() end, { desc = "recent files" })
map("n", "<leader>fz", function() Snacks.picker.lines() end, { desc = "fuzzy current buffer" })
map("n", "<leader>ma", function() Snacks.picker.marks() end, { desc = "marks" })
map("n", "<leader>cm", function() Snacks.picker.git_log() end, { desc = "git commits" })
map("n", "<leader>gt", function() Snacks.picker.git_status() end, { desc = "git status" })

-- ── terminal (nvchad.term -> Snacks terminal) ───────────────────────────────
map("t", "<C-x>", "<C-\\><C-n>", { desc = "escape terminal mode" })
map({ "n", "t" }, "<A-i>", function() Snacks.terminal() end, { desc = "toggle float term" })
map({ "n", "t" }, "<A-h>", function() Snacks.terminal(nil, { win = { position = "bottom" } }) end, { desc = "toggle horizontal term" })
map({ "n", "t" }, "<A-v>", function() Snacks.terminal(nil, { win = { position = "right" } }) end, { desc = "toggle vertical term" })
map("n", "<leader>h", function() Snacks.terminal(nil, { win = { position = "bottom" } }) end, { desc = "horizontal term" })
map("n", "<leader>v", function() Snacks.terminal(nil, { win = { position = "right" } }) end, { desc = "vertical term" })

-- ── which-key ───────────────────────────────────────────────────────────────
map("n", "<leader>wK", "<cmd>WhichKey<CR>", { desc = "which-key all keymaps" })
map("n", "<leader>wk", function() vim.cmd("WhichKey " .. vim.fn.input("WhichKey: ")) end, { desc = "which-key query" })
