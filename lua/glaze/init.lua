---@brief [[
--- glaze.nvim - Centralized Go binary management for Neovim plugins
---
--- A Mason/Lazy-style interface for managing Go binaries across multiple plugins.
--- Register your plugin's binaries once, update them all with a single command.
---
--- Usage:
---   require("glaze").setup({})
---   require("glaze").register("freeze", "github.com/charmbracelet/freeze")
---   require("glaze").register("glow", "github.com/charmbracelet/glow")
---@brief ]]

local M = {}

---@class GlazeBinary
---@field name string Binary name (executable name)
---@field url string Go module URL (without @version)
---@field plugin? string Plugin that registered this binary
---@field callback? fun(success: boolean) Optional callback after install/update

---@class GlazeConfig
---@field ui GlazeUIConfig
---@field concurrency number Max parallel installations
---@field go_cmd string[] Go command (supports goenv)

---@class GlazeUIConfig
---@field border string Border style
---@field size { width: number, height: number }
---@field icons GlazeIcons

---@class GlazeIcons
---@field pending string
---@field running string
---@field done string
---@field error string
---@field binary string

---@type GlazeConfig
M.config = {
  ui = {
    border = "rounded",
    size = { width = 0.7, height = 0.8 },
    icons = {
      pending = "○",
      running = "◐",
      done = "●",
      error = "✗",
      binary = "󰆍",
    },
  },
  concurrency = 4,
  go_cmd = { "go" },
}

---@type table<string, GlazeBinary>
M._binaries = {}

---@type number?
M._ns = nil

---@param opts? GlazeConfig
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  M._ns = vim.api.nvim_create_namespace("glaze")

  -- Auto-detect goenv
  if vim.fn.executable("goenv") == 1 then
    M.config.go_cmd = { "goenv", "exec", "go" }
  end

  -- Create commands
  vim.api.nvim_create_user_command("Glaze", function()
    require("glaze.view").open()
  end, { desc = "Open Glaze UI" })

  vim.api.nvim_create_user_command("GlazeUpdate", function(cmd)
    if cmd.args and cmd.args ~= "" then
      require("glaze.runner").update({ cmd.args })
    else
      require("glaze.runner").update_all()
    end
  end, {
    desc = "Update Go binaries",
    nargs = "?",
    complete = function()
      return vim.tbl_keys(M._binaries)
    end,
  })

  vim.api.nvim_create_user_command("GlazeInstall", function(cmd)
    if cmd.args and cmd.args ~= "" then
      require("glaze.runner").install({ cmd.args })
    else
      require("glaze.runner").install_missing()
    end
  end, {
    desc = "Install Go binaries",
    nargs = "?",
    complete = function()
      return vim.tbl_keys(M._binaries)
    end,
  })
end

---Register a binary for management.
---@param name string Binary/executable name
---@param url string Go module URL (e.g., "github.com/charmbracelet/freeze")
---@param opts? { plugin?: string, callback?: fun(success: boolean) }
function M.register(name, url, opts)
  opts = opts or {}
  M._binaries[name] = {
    name = name,
    url = url,
    plugin = opts.plugin,
    callback = opts.callback,
  }
end

---Unregister a binary.
---@param name string Binary name to unregister
function M.unregister(name)
  M._binaries[name] = nil
end

---Get all registered binaries.
---@return table<string, GlazeBinary>
function M.binaries()
  return M._binaries
end

---Check if a binary is installed.
---@param name string Binary name
---@return boolean
function M.is_installed(name)
  return vim.fn.executable(name) == 1
end

---Get binary installation status.
---@param name string Binary name
---@return "installed"|"missing"|"unknown"
function M.status(name)
  if not M._binaries[name] then
    return "unknown"
  end
  return M.is_installed(name) and "installed" or "missing"
end

return M
