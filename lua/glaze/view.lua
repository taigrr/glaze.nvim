---@brief [[
--- glaze.nvim view/UI
--- Lazy.nvim-style floating window with Charmbracelet aesthetic
---@brief ]]

local M = {}

---@type GlazeFloat?
M._float = nil

---@type number?
M._timer = nil

---@type table<string, boolean>
M._expanded = {}

---Line-to-binary mapping for cursor-aware actions.
---@type table<number, string>
M._line_map = {}

local SPINNERS = { "◐", "◓", "◑", "◒" }
local SPINNER_IDX = 1

---Get the binary name under the cursor.
---@return string? name Binary name or nil
function M._get_cursor_binary()
  if not M._float or not M._float:valid() then
    return nil
  end
  local line = vim.api.nvim_win_get_cursor(M._float.win)[1]
  return M._line_map[line]
end

---Open the Glaze UI.
function M.open()
  local Float = require("glaze.float").Float

  if M._float and M._float:valid() then
    M._float:close()
  end

  M._float = Float.new({
    title = " 🍩 Glaze ",
  })

  -- Set up keymaps — lazy.nvim-style controls
  M._float:map("U", function()
    require("glaze.runner").update_all()
  end, "Update all binaries")

  M._float:map("u", function()
    local name = M._get_cursor_binary()
    if name then
      require("glaze.runner").update({ name })
    else
      vim.notify("Move cursor to a binary line to update it", vim.log.levels.INFO)
    end
  end, "Update binary under cursor")

  M._float:map("i", function()
    local name = M._get_cursor_binary()
    if name then
      require("glaze.runner").install({ name })
    else
      vim.notify("Move cursor to a binary line to install it", vim.log.levels.INFO)
    end
  end, "Install binary under cursor")

  M._float:map("I", function()
    require("glaze.runner").install_missing()
  end, "Install all missing")

  M._float:map("x", function()
    require("glaze.runner").abort()
  end, "Abort")

  M._float:map("<CR>", function()
    M._toggle_details()
  end, "Toggle details")

  -- Subscribe to runner updates
  require("glaze.runner").on_update(function()
    M.render()
  end)

  -- Start update timer for spinner
  M._start_timer()

  M.render()
end

---@private
function M._start_timer()
  if M._timer then
    vim.fn.timer_stop(M._timer)
    M._timer = nil
  end

  M._timer = vim.fn.timer_start(100, function()
    if not M._float or not M._float:valid() then
      if M._timer then
        vim.fn.timer_stop(M._timer)
        M._timer = nil
      end
      return
    end

    local runner = require("glaze.runner")
    if runner.is_running() then
      SPINNER_IDX = (SPINNER_IDX % #SPINNERS) + 1
      vim.schedule(function()
        M.render()
      end)
    end
  end, { ["repeat"] = -1 })
end

---@private
---Toggle detail expansion for the binary under the cursor.
function M._toggle_details()
  local name = M._get_cursor_binary()
  if not name then
    return
  end
  M._expanded[name] = not M._expanded[name]
  M.render()
end

---Render the UI.
function M.render()
  if not M._float or not M._float:valid() then
    return
  end

  local glaze = require("glaze")
  local runner = require("glaze.runner")
  local checker = require("glaze.checker")
  local Text = require("glaze.text").Text

  local text = Text.new()
  text.wrap = M._float:width() - 4

  local icons = glaze.config.ui.icons

  -- Reset line map
  M._line_map = {}

  -- Header
  text:nl()
  text:append("  🍩 ", "GlazeIcon"):append("Glaze", "GlazeH1"):append("  Go Binary Manager", "GlazeComment"):nl()
  text:nl()

  -- Stats / Progress
  local stats = runner.stats()
  if stats.total > 0 then
    M._render_progress(text, stats)
    text:nl()
  end

  -- Keybinds
  text:append(" ", nil, { indent = 2 })
  text:append(" U ", "GlazeButtonActive"):append(" Update All ", "GlazeButton")
  text:append("  ")
  text:append(" u ", "GlazeButtonActive"):append(" Update ", "GlazeButton")
  text:append("  ")
  text:append(" I ", "GlazeButtonActive"):append(" Install All ", "GlazeButton")
  text:append("  ")
  text:append(" i ", "GlazeButtonActive"):append(" Install ", "GlazeButton")
  text:nl()
  text:append(" ", nil, { indent = 2 })
  text:append(" x ", "GlazeButtonActive"):append(" Abort ", "GlazeButton")
  text:append("  ")
  text:append(" ⏎ ", "GlazeButtonActive"):append(" Details ", "GlazeButton")
  text:append("  ")
  text:append(" q ", "GlazeButtonActive"):append(" Close ", "GlazeButton")
  text:nl():nl()

  -- Tasks section (if running)
  if stats.total > 0 then
    text:append("Tasks", "GlazeH2"):append(" (" .. stats.done .. "/" .. stats.total .. ")", "GlazeComment"):nl()
    text:nl()

    for _, task in ipairs(runner.tasks()) do
      M._render_task(text, task, icons)
    end
    text:nl()
  end

  -- Registered binaries
  local binaries = glaze.binaries()
  local binary_count = vim.tbl_count(binaries)

  -- Count updates available
  local updates_available = 0
  local update_info = checker.get_update_info()
  for _ in pairs(update_info) do
    updates_available = updates_available + 1
  end

  local header_suffix = " (" .. binary_count .. ")"
  if updates_available > 0 then
    header_suffix = header_suffix
  end
  text:append("Binaries", "GlazeH2"):append(header_suffix, "GlazeComment")
  if updates_available > 0 then
    text:append("  " .. updates_available .. " update(s) available", "GlazeRunning")
  end
  text:nl()
  text:nl()

  if binary_count == 0 then
    text:append("No binaries registered yet.", "GlazeComment", { indent = 4 }):nl()
    text:append("Use ", "GlazeComment", { indent = 4 })
    text:append('require("glaze").register(name, url)', "GlazeUrl")
    text:append(" to add binaries.", "GlazeComment"):nl()
  else
    -- Sort by name
    local sorted = {}
    for name, binary in pairs(binaries) do
      table.insert(sorted, { name = name, binary = binary })
    end
    table.sort(sorted, function(a, b)
      return a.name < b.name
    end)

    for _, item in ipairs(sorted) do
      M._render_binary(text, item.binary, icons, update_info)
    end
  end

  text:trim()

  -- Render to buffer
  vim.bo[M._float.buf].modifiable = true
  text:render(M._float.buf, glaze._ns)
  vim.bo[M._float.buf].modifiable = false
end

---@param text GlazeText
---@param stats table
---@private
function M._render_progress(text, stats)
  if not M._float then
    return
  end

  local width = M._float:width() - 6
  local done_ratio = stats.total > 0 and (stats.done / stats.total) or 0
  local done_width = math.floor(done_ratio * width + 0.5)

  if stats.done < stats.total then
    text:append_extmark({
      virt_text_win_col = 2,
      virt_text = { { string.rep("━", done_width), "GlazeProgressDone" } },
    })
    text:append_extmark({
      virt_text_win_col = 2 + done_width,
      virt_text = { { string.rep("━", width - done_width), "GlazeProgressTodo" } },
    })
  else
    text:append_extmark({
      virt_text_win_col = 2,
      virt_text = { { string.rep("━", width), "GlazeProgressDone" } },
    })
  end
end

---@param text GlazeText
---@param task GlazeTask
---@param icons GlazeIcons
---@private
function M._render_task(text, task, icons)
  local icon, icon_hl
  if task.status == "done" then
    icon, icon_hl = icons.done, "GlazeIconDone"
  elseif task.status == "error" then
    icon, icon_hl = icons.error, "GlazeIconError"
  elseif task.status == "running" then
    icon, icon_hl = SPINNERS[SPINNER_IDX], "GlazeIconRunning"
  else
    icon, icon_hl = icons.pending, "GlazePending"
  end

  local line_num = text:row()
  M._line_map[line_num] = task.binary.name

  text:append("  " .. icon .. " ", icon_hl)
  text:append(task.binary.name, "GlazeBinary")

  -- Time taken
  if task.end_time and task.start_time then
    local ms = (task.end_time - task.start_time) / 1e6
    text:append(string.format(" %.0fms", ms), "GlazeTime")
  end

  text:nl()

  -- Show output for errors or running tasks
  if task.status == "error" and #task.output > 0 then
    for _, line in ipairs(task.output) do
      text:append(line, "GlazeError", { indent = 6 }):nl()
    end
  end
end

---@param text GlazeText
---@param binary GlazeBinary
---@param icons GlazeIcons
---@param update_info? table<string, GlazeUpdateInfo>
---@private
function M._render_binary(text, binary, icons, update_info)
  local glaze = require("glaze")
  local installed = glaze.is_installed(binary.name)

  local icon = installed and icons.done or icons.pending
  local icon_hl = installed and "GlazeIconDone" or "GlazePending"

  local line_num = text:row()
  M._line_map[line_num] = binary.name

  text:append("  " .. icon .. " ", icon_hl)
  text:append(binary.name, "GlazeBinary")

  if binary.plugin then
    text:append(" (" .. binary.plugin .. ")", "GlazePlugin")
  end

  -- Show update available indicator
  if update_info and update_info[binary.name] then
    local info = update_info[binary.name]
    if info.has_update then
      text:append(" ⬆", "GlazeRunning")
      if info.installed_version and info.latest_version then
        text:append(" " .. info.installed_version .. " → " .. info.latest_version, "GlazeTime")
      end
    elseif info.installed_version then
      text:append(" ✓ " .. info.installed_version, "GlazeVersion")
    end
  end

  text:nl()

  -- Expanded details
  if M._expanded[binary.name] then
    text:append("URL: ", "GlazeComment", { indent = 6 })
    text:append(binary.url, "GlazeUrl"):nl()

    local bin_path = glaze.bin_path(binary.name)
    if bin_path then
      text:append("Path: ", "GlazeComment", { indent = 6 })
      text:append(bin_path, "GlazeUrl"):nl()
    end

    if binary.plugin then
      text:append("Plugin: ", "GlazeComment", { indent = 6 })
      text:append(binary.plugin, "GlazePlugin"):nl()
    end

    -- Show last error output from tasks
    local runner = require("glaze.runner")
    for _, task in ipairs(runner.tasks()) do
      if task.binary.name == binary.name and task.status == "error" and #task.output > 0 then
        text:append("Error: ", "GlazeError", { indent = 6 }):nl()
        for _, line in ipairs(task.output) do
          text:append(line, "GlazeError", { indent = 8 }):nl()
        end
        break
      end
    end

    text:nl()
  end
end

---Close the UI and clean up timer.
function M.close()
  if M._timer then
    vim.fn.timer_stop(M._timer)
    M._timer = nil
  end
  if M._float then
    M._float:close()
    M._float = nil
  end
end

return M
