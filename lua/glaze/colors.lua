---@brief [[
--- glaze.nvim color definitions
--- Doughnut-inspired palette with Lazy.nvim structure
--- When use_system_theming is enabled, uses standard nvim highlight groups instead
---@brief ]]

local M = {}

-- Doughnut-inspired palette
local palette = {
  frosting = "#FF6AD5", -- Primary pink accent
  lavender = "#C4A7E7", -- Soft purple
  mint = "#9FFFCB", -- Success green
  honey = "#FFD866", -- Warning yellow
  coral = "#FF6B6B", -- Error red
  sky = "#7DCFFF", -- URL blue
  grape = "#BB9AF7", -- Plugin purple
  ash = "#6E6A86", -- Muted gray
  shadow = "#3B3A52", -- Dark purple-gray
  ink = "#1A1B26", -- Background dark
}

-- Doughnut-inspired colors (pink/magenta theme)
M.colors = {
  -- Headers and accents
  H1 = { fg = palette.frosting, bold = true },
  H2 = { fg = palette.lavender, bold = true },
  Title = { fg = palette.frosting, bold = true },

  -- Status indicators
  Done = { fg = palette.mint },
  Running = { fg = palette.honey },
  Pending = { fg = palette.ash },
  Error = { fg = palette.coral, bold = true },

  -- Content
  Normal = "NormalFloat",
  Binary = { fg = palette.frosting },
  Url = { fg = palette.sky, italic = true },
  Plugin = { fg = palette.grape },
  Comment = "Comment",
  Dimmed = "Conceal",

  -- Progress bar
  ProgressDone = { fg = palette.frosting },
  ProgressTodo = { fg = palette.shadow },

  -- UI elements
  Border = { fg = palette.frosting },
  Button = "CursorLine",
  ButtonActive = { bg = palette.frosting, fg = palette.ink, bold = true },
  Key = { fg = palette.honey, bold = true },

  -- Version info
  Version = { fg = palette.mint },
  Time = { fg = palette.ash, italic = true },

  -- Icons
  Icon = { fg = palette.frosting },
  IconDone = { fg = palette.mint },
  IconError = { fg = palette.coral },
  IconRunning = { fg = palette.honey },

  Bold = { bold = true },
  Italic = { italic = true },
}

-- System theme colors (links to standard nvim groups)
M.system_colors = {
  -- Headers and accents
  H1 = "Title",
  H2 = "Title",
  Title = "Title",

  -- Status indicators
  Done = "DiagnosticOk",
  Running = "DiagnosticWarn",
  Pending = "Comment",
  Error = "DiagnosticError",

  -- Content
  Normal = "NormalFloat",
  Binary = "Identifier",
  Url = "Underlined",
  Plugin = "Special",
  Comment = "Comment",
  Dimmed = "Conceal",

  -- Progress bar
  ProgressDone = "DiagnosticOk",
  ProgressTodo = "Comment",

  -- UI elements
  Border = "FloatBorder",
  Button = "CursorLine",
  ButtonActive = "PmenuSel",
  Key = "SpecialKey",

  -- Version info
  Version = "DiagnosticOk",
  Time = "Comment",

  -- Icons
  Icon = "Special",
  IconDone = "DiagnosticOk",
  IconError = "DiagnosticError",
  IconRunning = "DiagnosticWarn",

  Bold = { bold = true },
  Italic = { italic = true },
}

M.did_setup = false

function M.set_hl()
  local glaze = require("glaze")
  local colors = glaze.config.ui.use_system_theming and M.system_colors or M.colors

  for name, def in pairs(colors) do
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
