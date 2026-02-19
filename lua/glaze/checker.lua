---@brief [[
--- glaze.nvim update checker
--- Checks for newer versions of registered Go binaries
---@brief ]]

local M = {}

---@class GlazeUpdateInfo
---@field name string Binary name
---@field installed_version? string Currently installed version
---@field latest_version? string Latest available version
---@field has_update boolean Whether an update is available

---@type table<string, GlazeUpdateInfo>
M._update_info = {}

---@type boolean
M._checking = false

local STATE_FILE = vim.fn.stdpath("data") .. "/glaze/state.json"

---Read persisted state from disk.
---@return table
local function read_state()
  local ok, content = pcall(vim.fn.readfile, STATE_FILE)
  if not ok or #content == 0 then
    return {}
  end
  local decode_ok, data = pcall(vim.json.decode, table.concat(content, "\n"))
  if not decode_ok then
    return {}
  end
  return data or {}
end

---Write state to disk.
---@param state table
local function write_state(state)
  local dir = vim.fn.fnamemodify(STATE_FILE, ":h")
  vim.fn.mkdir(dir, "p")
  local json = vim.json.encode(state)
  vim.fn.writefile({ json }, STATE_FILE)
end

---Get the frequency in seconds from config.
---@return number seconds
local function get_frequency_seconds()
  local glaze = require("glaze")
  local freq = glaze.config.auto_check.frequency
  if freq == "daily" then
    return 86400
  elseif freq == "weekly" then
    return 604800
  elseif type(freq) == "number" then
    return freq * 3600
  end
  return 86400
end

---Get installed version of a binary by parsing `go version -m` output.
---@param name string Binary name
---@param callback fun(version: string?)
local function get_installed_version(name, callback)
  local glaze = require("glaze")
  local bin_path = glaze.bin_path(name)
  if not bin_path then
    callback(nil)
    return
  end

  vim.fn.jobstart({ "go", "version", "-m", bin_path }, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if not data then
        callback(nil)
        return
      end
      local output = table.concat(data, "\n")
      -- Parse "mod\tmodule/path\tv1.2.3\th1:..." or "path\tmodule/path"
      local version = output:match("\tmod\t[^\t]+\t(v[^\t%s]+)")
        or output:match("\tpath\t[^\n]+\n[^\t]*\tmod\t[^\t]+\t(v[^\t%s]+)")
      callback(version)
    end,
    on_exit = function(_, code)
      if code ~= 0 then
        callback(nil)
      end
    end,
  })
end

---Check for the latest version of a module using go list.
---@param url string Module URL
---@param callback fun(version: string?)
local function get_latest_version(url, callback)
  local glaze = require("glaze")
  local cmd = vim.list_extend({}, glaze.config.go_cmd)
  vim.list_extend(cmd, { "list", "-m", "-json", url .. "@latest" })

  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    env = { GOFLAGS = "" },
    on_stdout = function(_, data)
      if not data then
        callback(nil)
        return
      end
      local output = table.concat(data, "\n")
      local decode_ok, result = pcall(vim.json.decode, output)
      if decode_ok and result and result.Version then
        callback(result.Version)
      else
        callback(nil)
      end
    end,
    on_exit = function(_, code)
      if code ~= 0 then
        callback(nil)
      end
    end,
  })
end

---Get cached update info.
---@return table<string, GlazeUpdateInfo>
function M.get_update_info()
  return M._update_info
end

---Check for updates on all registered binaries.
---@param opts? { silent?: boolean }
function M.check(opts)
  opts = opts or {}
  local glaze = require("glaze")
  local binaries = glaze.binaries()

  if vim.tbl_count(binaries) == 0 then
    if not opts.silent then
      vim.notify("Glaze: no binaries registered", vim.log.levels.INFO)
    end
    return
  end

  if M._checking then
    if not opts.silent then
      vim.notify("Glaze: already checking for updates", vim.log.levels.INFO)
    end
    return
  end

  M._checking = true
  local remaining = 0
  local updates_found = 0

  for name, binary in pairs(binaries) do
    remaining = remaining + 2 -- installed version + latest version

    local info = {
      name = name,
      installed_version = nil,
      latest_version = nil,
      has_update = false,
    }
    M._update_info[name] = info

    get_installed_version(name, function()
      -- callback receives version from the jobstart; re-check via closure
    end)
  end

  -- Simplified: check each binary sequentially-ish
  remaining = vim.tbl_count(binaries)
  for name, binary in pairs(binaries) do
    local info = M._update_info[name]

    get_installed_version(name, function(installed)
      info.installed_version = installed

      get_latest_version(binary.url, function(latest)
        info.latest_version = latest

        if installed and latest and installed ~= latest then
          info.has_update = true
          updates_found = updates_found + 1
        end

        remaining = remaining - 1
        if remaining <= 0 then
          M._checking = false

          -- Save check timestamp
          local state = read_state()
          state.last_check = os.time()
          state.update_info = {}
          for n, i in pairs(M._update_info) do
            state.update_info[n] = {
              installed_version = i.installed_version,
              latest_version = i.latest_version,
              has_update = i.has_update,
            }
          end
          write_state(state)

          -- Auto-update if enabled (requires auto_check to be enabled)
          if updates_found > 0 and glaze.config.auto_update.enabled and glaze.config.auto_check.enabled then
            vim.schedule(function()
              local to_update = {}
              for n, i in pairs(M._update_info) do
                if i.has_update then
                  table.insert(to_update, n)
                end
              end
              vim.notify("Glaze: auto-updating " .. #to_update .. " binary(ies)…", vim.log.levels.INFO)
              require("glaze.runner").update(to_update)
            end)
          elseif not opts.silent then
            if updates_found > 0 then
              vim.schedule(function()
                vim.notify("Glaze: " .. updates_found .. " update(s) available — run :GlazeUpdate", vim.log.levels.INFO)
              end)
            else
              vim.schedule(function()
                vim.notify("Glaze: all binaries up to date", vim.log.levels.INFO)
              end)
            end
          elseif updates_found > 0 then
            vim.schedule(function()
              vim.notify("Glaze: " .. updates_found .. " update(s) available — run :GlazeUpdate", vim.log.levels.INFO)
            end)
          end

          -- Refresh UI if open
          vim.schedule(function()
            local ok, view = pcall(require, "glaze.view")
            if ok and view._float and view._float:valid() then
              view.render()
            end
          end)
        end
      end)
    end)
  end
end

---Auto-check if enough time has passed since last check.
function M.auto_check()
  local state = read_state()
  local last_check = state.last_check or 0
  local now = os.time()
  local freq = get_frequency_seconds()

  -- Load cached update info
  if state.update_info then
    for name, info in pairs(state.update_info) do
      M._update_info[name] = {
        name = name,
        installed_version = info.installed_version,
        latest_version = info.latest_version,
        has_update = info.has_update or false,
      }
    end
  end

  if (now - last_check) >= freq then
    M.check({ silent = true })
  end
end

return M
