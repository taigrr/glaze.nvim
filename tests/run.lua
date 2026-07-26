package.path = table.concat({
  "./lua/?.lua",
  "./lua/?/init.lua",
  package.path,
}, ";")

local function assert_eq(actual, expected, message)
  if actual ~= expected then
    error((message or "assertion failed") .. ": expected " .. vim.inspect(expected) .. ", got " .. vim.inspect(actual))
  end
end

local function assert_truthy(value, message)
  if not value then
    error(message or "expected truthy value")
  end
end

local results = {}
local function test(name, fn)
  table.insert(results, { name = name, fn = fn })
end

local function reset_glaze()
  for _, module in ipairs({
    "glaze",
    "glaze.init",
    "glaze.runner",
    "glaze.checker",
    "glaze.view",
    "glaze.float",
    "glaze.text",
    "glaze.colors",
    "glaze.health",
  }) do
    package.loaded[module] = nil
  end

  for _, command in ipairs({ "Glaze", "GlazeUpdate", "GlazeInstall", "GlazeCheck" }) do
    pcall(vim.api.nvim_del_user_command, command)
  end

  return require("glaze")
end

test("setup is idempotent and preserves updated config", function()
  local glaze = reset_glaze()

  glaze.setup({ auto_check = { enabled = false }, concurrency = 2 })
  glaze.setup({ auto_check = { enabled = false }, concurrency = 7 })

  assert_eq(glaze.config.concurrency, 7, "second setup should update config")
  assert_truthy(vim.fn.exists(":Glaze") == 2, "Glaze command should exist")
  assert_truthy(vim.fn.exists(":GlazeUpdate") == 2, "GlazeUpdate command should exist")
  assert_truthy(vim.fn.exists(":GlazeInstall") == 2, "GlazeInstall command should exist")
  assert_truthy(vim.fn.exists(":GlazeCheck") == 2, "GlazeCheck command should exist")
end)

test("register batches auto-install requests into one install call", function()
  local glaze = reset_glaze()
  local runner = require("glaze.runner")
  local original_install = runner.install
  local install_calls = {}

  runner.install = function(names, opts)
    table.insert(install_calls, {
      names = vim.deepcopy(names),
      opts = vim.deepcopy(opts),
    })
  end

  glaze.setup({
    auto_check = { enabled = false },
    auto_install = { enabled = true, silent = true },
  })

  glaze.is_installed = function()
    return false
  end

  glaze.register("freeze", "github.com/charmbracelet/freeze", { plugin = "freeze.nvim" })
  glaze.register("glow", "github.com/charmbracelet/glow", { plugin = "glow.nvim" })
  vim.wait(350)

  assert_eq(#install_calls, 1, "auto-install should batch into one runner call")
  table.sort(install_calls[1].names)
  assert_eq(install_calls[1].names[1], "freeze")
  assert_eq(install_calls[1].names[2], "glow")
  assert_eq(install_calls[1].opts.silent, true, "batched install should preserve silent option")

  runner.install = original_install
end)

test("register merges duplicate plugin registrations without duplicates", function()
  local glaze = reset_glaze()

  glaze.setup({ auto_check = { enabled = false }, auto_install = { enabled = false } })
  glaze.register("freeze", "github.com/charmbracelet/freeze", { plugin = "freeze.nvim" })
  glaze.register("freeze", "github.com/charmbracelet/freeze", { plugin = "freeze.nvim" })
  glaze.register("freeze", "github.com/charmbracelet/freeze", { plugin = "blast.nvim" })

  local binary = glaze.binaries().freeze
  assert_truthy(binary ~= nil, "binary should be registered")
  table.sort(binary.plugins)
  assert_eq(#binary.plugins, 2, "plugins list should stay deduplicated")
  assert_eq(binary.plugins[1], "blast.nvim")
  assert_eq(binary.plugins[2], "freeze.nvim")
end)

test("runner marks failed job starts as errors", function()
  local glaze = reset_glaze()
  local runner = require("glaze.runner")
  local original_jobstart = vim.fn.jobstart

  local callback_result = "unset"
  glaze.setup({ auto_check = { enabled = false }, auto_install = { enabled = false } })
  glaze.register("fake-glaze-binary", "example.com/fake/glaze", {
    plugin = "fake.nvim",
    callback = function(success)
      callback_result = success
    end,
  })
  glaze.is_installed = function()
    return false
  end
  vim.fn.jobstart = function()
    return -1
  end

  runner.install({ "fake-glaze-binary" }, { silent = true })
  vim.wait(100)
  vim.fn.jobstart = original_jobstart

  local tasks = runner.tasks()
  assert_eq(#tasks, 1, "failed job start should create one task")
  assert_eq(tasks[1].status, "error", "failed job start should mark task as error")
  assert_truthy(tasks[1].output[1]:match("Failed to start command"), "failed job start should keep output")
  assert_eq(runner.is_running(), false, "failed job start should drain the runner")
  assert_eq(callback_result, false, "failed job start should notify callbacks with false")
end)

test("runner prunes finished tasks on a new operation", function()
  local glaze = reset_glaze()
  local runner = require("glaze.runner")
  local original_jobstart = vim.fn.jobstart

  glaze.setup({ auto_check = { enabled = false }, auto_install = { enabled = false } })
  glaze.register("fake-a", "example.com/fake/a")
  glaze.register("fake-b", "example.com/fake/b")
  glaze.is_installed = function()
    return false
  end
  vim.fn.jobstart = function()
    return -1
  end

  runner.install({ "fake-a" }, { silent = true })
  vim.wait(100)
  assert_eq(#runner.tasks(), 1, "first operation should leave one task")

  runner.install({ "fake-b" }, { silent = true })
  vim.wait(100)
  vim.fn.jobstart = original_jobstart

  assert_eq(#runner.tasks(), 1, "finished tasks from prior operation should be pruned")
  assert_eq(runner.tasks()[1].binary.name, "fake-b", "only the current task should remain")
end)

test("checker compares versions and prereleases correctly", function()
  local glaze = reset_glaze()
  glaze.setup({ auto_check = { enabled = false }, auto_install = { enabled = false } })
  local is_newer = require("glaze.checker")._is_newer

  assert_eq(is_newer("v1.0.0", "v1.1.0"), true, "minor bump is newer")
  assert_eq(is_newer("v1.10.0", "v1.9.0"), false, "no false-positive on numeric ordering")
  assert_eq(is_newer("1.0.0", "v1.0.0"), false, "v-prefix normalized, equal")
  assert_eq(is_newer("v1.0.0-rc1", "v1.0.0"), true, "release is newer than prerelease")
  assert_eq(is_newer("v1.0.0", "v1.0.0-rc1"), false, "prerelease is not newer than release")
  assert_eq(is_newer("v1.0.0-rc1", "v1.0.0-rc2"), true, "rc1 -> rc2")
  assert_eq(is_newer("v1.0.0-rc2", "v1.0.0-rc10"), true, "rc2 -> rc10 (multi-digit)")
  assert_eq(is_newer("v1.0.0-rc10", "v1.0.0-rc2"), false, "rc10 is not older than rc2")
  assert_eq(
    is_newer("v0.0.0-20240101000000-aaaaaaaaaaaa", "v0.0.0-20240202000000-bbbbbbbbbbbb"),
    true,
    "pseudo-version date progression"
  )
end)

for _, case in ipairs(results) do
  local ok, err = pcall(case.fn)
  if not ok then
    io.stderr:write("FAIL: " .. case.name .. "\n" .. tostring(err) .. "\n")
    os.exit(1)
  end
  print("PASS: " .. case.name)
end
