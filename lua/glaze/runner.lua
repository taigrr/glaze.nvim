---@brief [[
--- glaze.nvim task runner
--- Handles parallel Go binary installation/updates
---@brief ]]

local M = {}

---@class GlazeTask
---@field binary GlazeBinary
---@field status "pending"|"running"|"done"|"error"
---@field output string[]
---@field start_time? number
---@field end_time? number
---@field job_id? number

---@type GlazeTask[]
M._tasks = {}

---@type function?
M._on_update = nil

---@type boolean
M._running = false

---Get all current tasks.
---@return GlazeTask[]
function M.tasks()
  return M._tasks
end

---Check if runner is active.
---@return boolean
function M.is_running()
  return M._running
end

---Set update callback (called when task status changes).
---@param fn function
function M.on_update(fn)
  M._on_update = fn
end

---@private
function M._notify()
  if M._on_update then
    vim.schedule(M._on_update)
  end
end

---@param binary GlazeBinary
---@return GlazeTask
local function create_task(binary)
  return {
    binary = binary,
    status = "pending",
    output = {},
  }
end

---@param task GlazeTask
local function run_task(task)
  local glaze = require("glaze")
  local cmd = vim.list_extend({}, glaze.config.go_cmd)
  table.insert(cmd, "install")
  table.insert(cmd, task.binary.url .. "@latest")

  task.status = "running"
  task.start_time = vim.uv.hrtime()
  task.output = {}
  M._notify()

  task.job_id = vim.fn.jobstart(cmd, {
    on_stdout = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            table.insert(task.output, line)
          end
        end
      end
    end,
    on_stderr = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            table.insert(task.output, line)
          end
        end
      end
    end,
    on_exit = function(_, code)
      task.end_time = vim.uv.hrtime()
      task.status = code == 0 and "done" or "error"
      task.job_id = nil

      -- Call binary callback if set
      if task.binary.callback then
        vim.schedule(function()
          task.binary.callback(code == 0)
        end)
      end

      M._notify()
      M._process_queue()
    end,
  })
end

---@private
function M._process_queue()
  local glaze = require("glaze")
  local running = 0
  local pending = {}

  for _, task in ipairs(M._tasks) do
    if task.status == "running" then
      running = running + 1
    elseif task.status == "pending" then
      table.insert(pending, task)
    end
  end

  -- Start pending tasks up to concurrency limit
  local to_start = math.min(#pending, glaze.config.concurrency - running)
  for i = 1, to_start do
    run_task(pending[i])
  end

  -- Check if all done
  if running == 0 and #pending == 0 then
    M._running = false
    M._notify()
  end
end

---Run tasks for specified binaries.
---@param names string[]
---@param mode "install"|"update"
local function run(names, mode)
  local glaze = require("glaze")

  -- Reject if already running (race condition fix)
  if M._running then
    vim.notify("Glaze: tasks already running. Wait or abort first.", vim.log.levels.WARN)
    return
  end

  -- Check for Go
  local go_check = glaze.config.go_cmd[1]
  if vim.fn.executable(go_check) ~= 1 then
    vim.notify("Go is not installed. Please install Go first: https://go.dev/dl/", vim.log.levels.ERROR)
    return
  end

  -- Filter binaries
  local binaries = {}
  for _, name in ipairs(names) do
    local binary = glaze._binaries[name]
    if binary then
      if mode == "install" and glaze.is_installed(name) then
        -- Skip already installed
      else
        table.insert(binaries, binary)
      end
    else
      vim.notify("Unknown binary: " .. name, vim.log.levels.WARN)
    end
  end

  if #binaries == 0 then
    if mode == "install" then
      vim.notify("All binaries already installed", vim.log.levels.INFO)
    end
    return
  end

  -- Create tasks
  M._tasks = {}
  for _, binary in ipairs(binaries) do
    table.insert(M._tasks, create_task(binary))
  end

  M._running = true
  M._notify()
  M._process_queue()

  -- Open UI
  require("glaze.view").open()
end

---Update specific binaries.
---@param names string[]
function M.update(names)
  run(names, "update")
end

---Update all registered binaries.
function M.update_all()
  local glaze = require("glaze")
  run(vim.tbl_keys(glaze._binaries), "update")
end

---Install specific binaries.
---@param names string[]
function M.install(names)
  run(names, "install")
end

---Install all missing binaries.
function M.install_missing()
  local glaze = require("glaze")
  local missing = {}
  for name, _ in pairs(glaze._binaries) do
    if not glaze.is_installed(name) then
      table.insert(missing, name)
    end
  end
  if #missing > 0 then
    run(missing, "install")
  else
    vim.notify("All binaries already installed", vim.log.levels.INFO)
  end
end

---Abort all running tasks.
function M.abort()
  for _, task in ipairs(M._tasks) do
    if task.job_id then
      vim.fn.jobstop(task.job_id)
      task.status = "error"
      table.insert(task.output, "Aborted by user")
    end
  end
  M._running = false
  M._notify()
end

---Get task statistics.
---@return { total: number, done: number, error: number, running: number, pending: number }
function M.stats()
  local stats = { total = #M._tasks, done = 0, error = 0, running = 0, pending = 0 }
  for _, task in ipairs(M._tasks) do
    stats[task.status] = (stats[task.status] or 0) + 1
  end
  return stats
end

return M
