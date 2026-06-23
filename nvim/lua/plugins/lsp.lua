-- LSP servers ported from the old NvChad config (lua/configs/lspconfig.lua).
return {
  -- Docker-backed language servers. NOTE: in your old config this was only
  -- `require("lspcontainers").setup({})` and was never attached to any server
  -- (all servers below used normal / `bundle exec` commands), so it was inert.
  -- Kept the same way for fidelity. To actually run a server in Docker, set its
  -- `cmd = require("lspcontainers").command("<server>")` in the servers table.
  {
    "lspcontainers/lspcontainers.nvim",
    lazy = false,
    config = function()
      require("lspcontainers").setup({})
    end,
  },

  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- Ruby: use the globally-installed `ruby-lsp` gem (mise ruby), NOT Mason.
        -- The old config hardcoded `bundle exec ruby-lsp` + a cwd/Gemfile env,
        -- which failed with "Could not locate Gemfile" outside a bundler project.
        -- Global ruby-lsp is the recommended setup: it auto-composes a project's
        -- bundle when a Gemfile is present and just works when there isn't one.
        -- Install/upgrade with: gem install ruby-lsp
        -- root_dir uses nvim 0.11's native signature (bufnr, on_dir): root at the
        -- Gemfile/.git when in a project, else fall back to the file's own dir so a
        -- single .rb file still attaches (lspconfig's default would return nil and
        -- skip the server entirely).
        ruby_lsp = {
          mason = false,
          root_dir = function(bufnr, on_dir)
            local fname = vim.api.nvim_buf_get_name(bufnr)
            local root = vim.fs.root(bufnr, { "Gemfile", ".git", ".ruby-lsp" })
            on_dir(root or vim.fs.dirname(fname))
          end,
        },
        html = {},
        cssls = {},
        lua_ls = {
          settings = {
            Lua = { diagnostics = { globals = { "vim" } } },
          },
        },
      },
    },
  },
}
