---@brief [[
--- glaze.nvim color definitions
--- Charmbracelet-inspired palette with Lazy.nvim structure
---@brief ]]

local M = {}

-- Charmbracelet-inspired colors (pink/magenta theme)
M.colors = {
  -- Headers and accents
  H1 = { fg = "#FF6AD5", bold = true }, -- Charm pink
  H2 = { fg = "#C4A7E7", bold = true }, -- Soft purple
  Title = { fg = "#FF6AD5", bold = true },

  -- Status indicators
  Done = { fg = "#9FFFCB" }, -- Mint green (success)
  Running = { fg = "#FFD866" }, -- Warm yellow (in progress)
  Pending = { fg = "#6E6A86" }, -- Muted gray
  Error = { fg = "#FF6B6B", bold = true }, -- Soft red

  -- Content
  Normal = "NormalFloat",
  Binary = { fg = "#FF6AD5" }, -- Charm pink for binary names
  Url = { fg = "#7DCFFF", italic = true }, -- Bright blue for URLs
  Plugin = { fg = "#BB9AF7" }, -- Purple for plugin names
  Comment = "Comment",
  Dimmed = "Conceal",

  -- Progress bar
  ProgressDone = { fg = "#FF6AD5" }, -- Charm pink
  ProgressTodo = { fg = "#3B3A52" }, -- Dark purple-gray

  -- UI elements
  Border = { fg = "#FF6AD5" },
  Button = "CursorLine",
  ButtonActive = { bg = "#FF6AD5", fg = "#1A1B26", bold = true },
  Key = { fg = "#FFD866", bold = true }, -- Keybind highlights

  -- Version info
  Version = { fg = "#9FFFCB" },
  Time = { fg = "#6E6A86", italic = true },

  -- Icons
  Icon = { fg = "#FF6AD5" },
  IconDone = { fg = "#9FFFCB" },
  IconError = { fg = "#FF6B6B" },
  IconRunning = { fg = "#FFD866" },

  Bold = { bold = true },
  Italic = { italic = true },
}

M.did_setup = false

function M.set_hl()
  for name, def in pairs(M.colors) do
    local hl = type(def) == "table" and def or { link = def }
    hl.default = true
    vim.api.nvim_set_hl(0, "Glaze" .. name, hl)
  end
end

function M.setup()
  if M.did_setup then
    return
  end
  M.did_setup = true

  M.set_hl()

  vim.api.nvim_create_autocmd("ColorScheme", {
    callback = M.set_hl,
  })
end

return M
