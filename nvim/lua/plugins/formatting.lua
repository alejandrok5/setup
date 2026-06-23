-- Formatters ported from the old NvChad config (lua/configs/conform.lua).
-- Format-on-save is already ON by default in LazyVim (toggle with <leader>uf;
-- <leader>fm also formats now, per config/keymaps.lua).
return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        lua = { "stylua" },
        ruby = { "rubocop" },
        eruby = { "erb_formatter" },
        css = { "prettier" },
        html = { "prettier" },
      },
    },
  },

  -- Install the formatters via Mason. stylua + prettier come from Mason;
  -- rubocop / erb_formatter usually come from your Ruby project (bundle).
  {
    "mason-org/mason.nvim", -- renamed from williamboman/mason.nvim
    opts = { ensure_installed = { "stylua", "prettier" } },
  },
}
