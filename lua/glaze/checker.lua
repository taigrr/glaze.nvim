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

---Parse a version string into comparable components.
---Handles semver (v1.2.3), pseudo-versions (v0.0.0-20240122...), etc.
---@param version string
---@return number[] parts, string? prerelease, number? pseudo_ts
local function parse_version(version)
  if not version then
    return {}, nil, nil
  end

  -- Strip leading 'v' and any build metadata (semver §10, e.g. +incompatible)
  local v = version:gsub("^v", ""):gsub("%+.*$", "")

  -- Detect the 14-digit timestamp embedded in any Go pseudo-version form
  -- (v0.0.0-<ts>-<hash>, vX.Y.Z-0.<ts>-<hash>, vX.Y.Z-pre.0.<ts>-<hash>).
  local pseudo_ts = v:match("(%d%d%d%d%d%d%d%d%d%d%d%d%d%d)%-%x+$")

  -- Split by hyphen to separate prerelease
  local base, prerelease = v:match("^([^-]+)-?(.*)$")
  if prerelease == "" then
    prerelease = nil
  end

  -- Parse numeric parts
  local parts = {}
  for num in (base or v):gmatch("(%d+)") do
    table.insert(parts, tonumber(num) or 0)
  end

  return parts, prerelease, pseudo_ts and tonumber(pseudo_ts) or nil
end

---Compare two prerelease strings per semver §11 (dot-separated identifiers,
---numeric compared numerically, alphanumeric lexically, numeric < alphanumeric).
---@param a string
---@param b string
---@return number -1 if a<b, 0 if equal, 1 if a>b
local function compare_prerelease(a, b)
  local a_ids, b_ids = {}, {}
  for id in a:gmatch("[^.]+") do
    table.insert(a_ids, id)
  end
  for id in b:gmatch("[^.]+") do
    table.insert(b_ids, id)
  end

  local max_len = math.max(#a_ids, #b_ids)
  for i = 1, max_len do
    local ai, bi = a_ids[i], b_ids[i]
    -- A larger set of identifiers wins when all preceding are equal.
    if ai == nil then
      return -1
    elseif bi == nil then
      return 1
    end

    local an, bn = tonumber(ai), tonumber(bi)
    if an and bn then
      if an ~= bn then
        return an < bn and -1 or 1
      end
    elseif an and not bn then
      return -1 -- numeric identifiers have lower precedence
    elseif bn and not an then
      return 1
    elseif ai ~= bi then
      -- Alphanumeric: split into text prefix and trailing number so
      -- e.g. "rc2" < "rc10" compares numerically after the shared prefix.
      local a_text, a_num = ai:match("^(.-)(%d*)$")
      local b_text, b_num = bi:match("^(.-)(%d*)$")
      if a_text == b_text and a_num ~= "" and b_num ~= "" then
        local na, nb = tonumber(a_num), tonumber(b_num)
        if na ~= nb then
          return na < nb and -1 or 1
        end
      end
      return ai < bi and -1 or 1
    end
  end

  return 0
end

---Compare two versions. Returns true if `latest` is newer than `installed`.
---@param installed string
---@param latest string
---@return boolean
local function is_newer(installed, latest)
  if not installed or not latest then
    return false
  end

  local inst_parts, inst_pre, inst_ts = parse_version(installed)
  local lat_parts, lat_pre, lat_ts = parse_version(latest)

  -- Compare numeric parts
  local max_len = math.max(#inst_parts, #lat_parts)
  for i = 1, max_len do
    local inst_num = inst_parts[i] or 0
    local lat_num = lat_parts[i] or 0
    if lat_num > inst_num then
      return true
    elseif lat_num < inst_num then
      return false
    end
  end

  -- Same numeric base. Prefer pseudo-version timestamps when both are pseudos.
  if inst_ts and lat_ts then
    return lat_ts > inst_ts
  end

  -- Same numeric version - check prerelease
  -- No prerelease > has prerelease (1.0.0 > 1.0.0-beta)
  if inst_pre and not lat_pre then
    return true -- latest has no prerelease, so it's newer
  elseif not inst_pre and lat_pre then
    return false -- installed has no prerelease, latest does
  elseif inst_pre and lat_pre then
    -- Both prereleases on the same base: semver identifier comparison
    -- catches rc1->rc2, rc2->rc10, and same-base date progression.
    return compare_prerelease(inst_pre, lat_pre) < 0
  end

  -- Both lack prerelease, versions are equal
  return false
end

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

  local done = false
  local function finish(version)
    if done then
      return
    end
    done = true
    callback(version)
  end

  local job_id = vim.fn.jobstart({ "go", "version", "-m", bin_path }, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if not data then
        finish(nil)
        return
      end
      local output = table.concat(data, "\n")
      -- Parse "mod\tmodule/path\tv1.2.3\th1:..." or "path\tmodule/path"
      local version = output:match("\tmod\t[^\t]+\t(v[^\t%s]+)")
        or output:match("\tpath\t[^\n]+\n[^\t]*\tmod\t[^\t]+\t(v[^\t%s]+)")
      finish(version)
    end,
    on_exit = function(_, code)
      if code ~= 0 then
        finish(nil)
      end
    end,
  })

  if job_id <= 0 then
    finish(nil)
  end
end

---Check for the latest version of a module using go list.
---@param url string Module URL
---@param callback fun(version: string?)
local function get_latest_version(url, callback)
  local glaze = require("glaze")
  local cmd = vim.list_extend({}, glaze.config.go_cmd)
  vim.list_extend(cmd, { "list", "-m", "-json", url .. "@latest" })

  local done = false
  local function finish(version)
    if done then
      return
    end
    done = true
    callback(version)
  end

  local job_id = vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    env = { GOFLAGS = "" },
    on_stdout = function(_, data)
      if not data then
        finish(nil)
        return
      end
      local output = table.concat(data, "\n")
      local decode_ok, result = pcall(vim.json.decode, output)
      if decode_ok and result and result.Version then
        finish(result.Version)
      else
        finish(nil)
      end
    end,
    on_exit = function(_, code)
      if code ~= 0 then
        finish(nil)
      end
    end,
  })

  if job_id <= 0 then
    finish(nil)
  end
end

---Get cached update info.
---@return table<string, GlazeUpdateInfo>
function M.get_update_info()
  return M._update_info
end

---Refresh version info for a single binary (called after install/update).
---@param name string Binary name
---@param callback? fun() Optional callback when done
function M.refresh_version(name, callback)
  local glaze = require("glaze")
  local binary = glaze._binaries[name]
  if not binary then
    if callback then
      callback()
    end
    return
  end

  get_installed_version(name, function(installed)
    local info = M._update_info[name]
      or {
        name = name,
        installed_version = nil,
        latest_version = nil,
        has_update = false,
      }
    info.installed_version = installed

    -- If we have latest version cached, check if still needs update
    if info.latest_version and installed then
      info.has_update = is_newer(installed, info.latest_version)
    else
      info.has_update = false
    end

    M._update_info[name] = info

    -- Persist to state
    local state = read_state()
    state.update_info = state.update_info or {}
    state.update_info[name] = {
      installed_version = info.installed_version,
      latest_version = info.latest_version,
      has_update = info.has_update,
    }
    write_state(state)

    -- Refresh UI if open
    vim.schedule(function()
      local ok, view = pcall(require, "glaze.view")
      if ok and view._float and view._float:valid() then
        view.render()
      end
      if callback then
        callback()
      end
    end)
  end)
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
  local updates_found = 0
  local remaining = vim.tbl_count(binaries)
  for name, binary in pairs(binaries) do
    local info = {
      name = name,
      installed_version = nil,
      latest_version = nil,
      has_update = false,
    }
    M._update_info[name] = info

    get_installed_version(name, function(installed)
      info.installed_version = installed

      get_latest_version(binary.url, function(latest)
        info.latest_version = latest

        if is_newer(installed, latest) then
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
                vim.notify(
                  "Glaze: " .. updates_found .. " update(s) available — run :GlazeUpdate",
                  vim.log.levels.INFO
                )
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

---@private Exposed for testing.
M._is_newer = is_newer

return M
