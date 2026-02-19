---@brief [[
--- glaze.nvim view/UI
--- Lazy.nvim-style floating window with Charmbracelet aesthetic
---@brief ]]

local M = {}

---@type GlazeFloat?
M._float = nil

---@type number?
M._timer = nil

local SPINNERS = { "◐", "◓", "◑", "◒" }
local SPINNER_IDX = 1

---Open the Glaze UI.
function M.open()
  local Float = require("glaze.float").Float

  if M._float and M._float:valid() then
    M._float:close()
  end

  M._float = Float.new({
    title = " 󱓞 Glaze ",
  })

  -- Set up keymaps
  M._float:map("u", function()
    require("glaze.runner").update_all()
  end, "Update all")

  M._float:map("i", function()
    require("glaze.runner").install_missing()
  end, "Install missing")

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
function M._toggle_details()
  -- TODO: Implement detail expansion
end

---Render the UI.
function M.render()
  if not M._float or not M._float:valid() then
    return
  end

  local glaze = require("glaze")
  local runner = require("glaze.runner")
  local Text = require("glaze.text").Text

  local text = Text.new()
  text.wrap = M._float:width() - 4

  local icons = glaze.config.ui.icons

  -- Header
  text:nl()
  text:append("  ", "GlazeIcon"):append("Glaze", "GlazeH1"):append("  Go Binary Manager", "GlazeComment"):nl()
  text:nl()

  -- Stats / Progress
  local stats = runner.stats()
  if stats.total > 0 then
    M._render_progress(text, stats)
    text:nl()
  end

  -- Keybinds
  text:append(" ", nil, { indent = 2 })
  text:append(" u ", "GlazeButtonActive"):append(" Update ", "GlazeButton")
  text:append("  ")
  text:append(" i ", "GlazeButtonActive"):append(" Install ", "GlazeButton")
  text:append("  ")
  text:append(" x ", "GlazeButtonActive"):append(" Abort ", "GlazeButton")
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

  text:append("Binaries", "GlazeH2"):append(" (" .. binary_count .. ")", "GlazeComment"):nl()
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
      M._render_binary(text, item.binary, icons)
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
    text:append("", {
      virt_text_win_col = 2,
      virt_text = { { string.rep("━", done_width), "GlazeProgressDone" } },
    })
    text:append("", {
      virt_text_win_col = 2 + done_width,
      virt_text = { { string.rep("━", width - done_width), "GlazeProgressTodo" } },
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
---@private
function M._render_binary(text, binary, icons)
  local glaze = require("glaze")
  local installed = glaze.is_installed(binary.name)

  local icon = installed and icons.done or icons.pending
  local icon_hl = installed and "GlazeIconDone" or "GlazePending"

  text:append("  " .. icon .. " ", icon_hl)
  text:append(binary.name, "GlazeBinary")

  if binary.plugin then
    text:append(" (" .. binary.plugin .. ")", "GlazePlugin")
  end

  text:nl()
  text:append(binary.url, "GlazeUrl", { indent = 6 }):nl()
end

---Close the UI.
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
