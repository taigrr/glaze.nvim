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
---@field plugins string[] Plugins that registered this binary
---@field callbacks table<string, fun(success: boolean)> Callbacks keyed by plugin name

---@class GlazeAutoCheckConfig
---@field enabled? boolean Whether to auto-check for updates
---@field frequency? string|number Frequency: "daily", "weekly", or hours as number

---@class GlazeAutoInstallConfig
---@field enabled? boolean Whether to auto-install missing binaries on register
---@field silent? boolean Suppress notifications during auto-install

---@class GlazeAutoUpdateConfig
---@field enabled? boolean Whether to auto-update binaries when newer versions are found (requires auto_check)

---@class GlazeConfig
---@field ui? GlazeUIConfig
---@field concurrency? number Max parallel installations
---@field go_cmd? string[] Go command (supports goenv)
---@field auto_install? GlazeAutoInstallConfig
---@field auto_check? GlazeAutoCheckConfig
---@field auto_update? GlazeAutoUpdateConfig

---@class GlazeUIConfig
---@field border? string Border style
---@field size? { width: number, height: number }
---@field icons? GlazeIcons
---@field use_system_theming? boolean Use nvim highlight groups instead of doughnut colors

---@class GlazeIcons
---@field pending? string
---@field running? string
---@field done? string
---@field error? string
---@field binary? string

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
    use_system_theming = false,
  },
  concurrency = 4,
  go_cmd = { "go" },
  auto_install = {
    enabled = true,
    silent = false,
  },
  auto_check = {
    enabled = true,
    frequency = "daily",
  },
  auto_update = {
    enabled = false,
  },
}

---@type table<string, GlazeBinary>
M._binaries = {}

---@type number?
M._ns = nil

---@type table<string, boolean> Binaries queued for auto-install
M._auto_install_queue = {}

---@type number? Timer for batched auto-install
M._auto_install_timer = nil

---@param name string
---@param fn function
---@param opts table
local function ensure_user_command(name, fn, opts)
  if vim.fn.exists(":" .. name) ~= 2 then
    vim.api.nvim_create_user_command(name, fn, opts)
  end
end

---@param opts? GlazeConfig
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  M._ns = vim.api.nvim_create_namespace("glaze")

  -- Auto-detect goenv
  if vim.fn.executable("goenv") == 1 then
    M.config.go_cmd = { "goenv", "exec", "go" }
  end

  -- Create commands
  ensure_user_command("Glaze", function()
    require("glaze.view").open()
  end, { desc = "Open Glaze UI" })

  ensure_user_command("GlazeUpdate", function(cmd)
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

  ensure_user_command("GlazeInstall", function(cmd)
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

  ensure_user_command("GlazeCheck", function()
    require("glaze.checker").check()
  end, { desc = "Check for binary updates" })

  -- Auto-check for updates
  if M.config.auto_check.enabled then
    vim.defer_fn(function()
      require("glaze.checker").auto_check()
    end, 3000)
  end
end

---Register a binary for management.
---If auto_install is enabled and the binary is missing, it will be installed automatically.
---@param name string Binary/executable name
---@param url string Go module URL (e.g., "github.com/charmbracelet/freeze")
---@param opts? { plugin?: string, callback?: fun(success: boolean) }
function M.register(name, url, opts)
  opts = opts or {}
  local plugin = opts.plugin or "unknown"

  -- Check if this URL is already registered under a different name
  for existing_name, binary in pairs(M._binaries) do
    if binary.url == url and existing_name ~= name then
      -- Same URL, different name - merge into existing entry
      if not vim.tbl_contains(binary.plugins, plugin) then
        table.insert(binary.plugins, plugin)
      end
      if opts.callback then
        binary.callbacks[plugin] = opts.callback
      end
      return
    end
  end

  -- Check if this name is already registered
  local existing = M._binaries[name]
  if existing then
    -- Merge plugin into existing entry
    if not vim.tbl_contains(existing.plugins, plugin) then
      table.insert(existing.plugins, plugin)
    end
    if opts.callback then
      existing.callbacks[plugin] = opts.callback
    end
    return
  end

  -- New binary registration
  M._binaries[name] = {
    name = name,
    url = url,
    plugins = opts.plugin and { opts.plugin } or {},
    callbacks = opts.callback and { [plugin] = opts.callback } or {},
  }

  -- Queue for auto-install if enabled and binary is missing.
  -- Uses a batched timer so multiple registers don't race.
  if M.config.auto_install.enabled and not M.is_installed(name) then
    M._auto_install_queue[name] = true
    if M._auto_install_timer then
      vim.fn.timer_stop(M._auto_install_timer)
    end
    M._auto_install_timer = vim.fn.timer_start(200, function()
      M._auto_install_timer = nil
      vim.schedule(function()
        local to_install = {}
        for queued_name, _ in pairs(M._auto_install_queue) do
          if not M.is_installed(queued_name) then
            table.insert(to_install, queued_name)
          end
        end
        M._auto_install_queue = {}
        if #to_install > 0 then
          if not M.config.auto_install.silent then
            vim.notify("[glaze] Auto-installing " .. table.concat(to_install, ", ") .. "…", vim.log.levels.INFO)
          end
          require("glaze.runner").install(to_install, { silent = M.config.auto_install.silent })
        end
      end)
    end)
  end
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
---Checks PATH, $GOBIN, $GOPATH/bin, and $(go env GOBIN).
---@param name string Binary name
---@return boolean
function M.is_installed(name)
  -- Check PATH first
  if vim.fn.executable(name) == 1 then
    return true
  end

  -- Check $GOBIN
  local gobin = os.getenv("GOBIN")
  if gobin and gobin ~= "" then
    local path = gobin .. "/" .. name
    if vim.uv.fs_stat(path) then
      return true
    end
  end

  -- Check $GOPATH/bin
  local gopath = os.getenv("GOPATH")
  if gopath and gopath ~= "" then
    local path = gopath .. "/bin/" .. name
    if vim.uv.fs_stat(path) then
      return true
    end
  end

  -- Check default ~/go/bin
  local home = os.getenv("HOME") or os.getenv("USERPROFILE") or ""
  local default_path = home .. "/go/bin/" .. name
  if vim.uv.fs_stat(default_path) then
    return true
  end

  return false
end

---Get the install path for a binary if found.
---@param name string Binary name
---@return string? path Full path to the binary, or nil
function M.bin_path(name)
  -- Check PATH
  local which = vim.fn.exepath(name)
  if which ~= "" then
    return which
  end

  -- Check $GOBIN
  local gobin = os.getenv("GOBIN")
  if gobin and gobin ~= "" then
    local path = gobin .. "/" .. name
    if vim.uv.fs_stat(path) then
      return path
    end
  end

  -- Check $GOPATH/bin
  local gopath = os.getenv("GOPATH")
  if gopath and gopath ~= "" then
    local path = gopath .. "/bin/" .. name
    if vim.uv.fs_stat(path) then
      return path
    end
  end

  -- Check default ~/go/bin
  local home = os.getenv("HOME") or os.getenv("USERPROFILE") or ""
  local default_path = home .. "/go/bin/" .. name
  if vim.uv.fs_stat(default_path) then
    return default_path
  end

  return nil
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
