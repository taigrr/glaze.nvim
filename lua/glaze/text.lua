---@brief [[
--- glaze.nvim text rendering (based on lazy.nvim)
--- Handles buffered text with highlight segments
---@brief ]]

local M = {}

---@class GlazeTextSegment
---@field str string
---@field hl? string|GlazeExtmark

---@class GlazeExtmark
---@field hl_group? string
---@field col? number
---@field end_col? number
---@field virt_text? table
---@field virt_text_win_col? number

---@class GlazeText
---@field _lines GlazeTextSegment[][]
---@field padding number
---@field wrap number
local Text = {}

function Text.new()
  local self = setmetatable({}, { __index = Text })
  self._lines = {}
  self.padding = 2
  self.wrap = 80
  return self
end

---@param str string
---@param hl? string|GlazeExtmark
---@param opts? { indent?: number, wrap?: boolean }
---@return GlazeText
function Text:append(str, hl, opts)
  opts = opts or {}
  if #self._lines == 0 then
    self:nl()
  end

  local lines = vim.split(str, "\n")
  for i, line in ipairs(lines) do
    if opts.indent then
      line = string.rep(" ", opts.indent) .. line
    end
    if i > 1 then
      self:nl()
    end
    -- Handle wrap
    if opts.wrap and str ~= "" and self:col() > 0 and self:col() + vim.fn.strwidth(line) + self.padding > self.wrap then
      self:nl()
    end
    table.insert(self._lines[#self._lines], { str = line, hl = hl })
  end
  return self
end

---Append a virtual text extmark on the current line (empty string segment).
---@param extmark GlazeExtmark Extmark options (virt_text, virt_text_win_col, etc.)
---@return GlazeText
function Text:append_extmark(extmark)
  if #self._lines == 0 then
    self:nl()
  end
  table.insert(self._lines[#self._lines], { str = "", hl = extmark })
  return self
end

---@return GlazeText
function Text:nl()
  table.insert(self._lines, {})
  return self
end

---@return number
function Text:row()
  return #self._lines == 0 and 1 or #self._lines
end

---@return number
function Text:col()
  if #self._lines == 0 then
    return 0
  end
  local width = 0
  for _, segment in ipairs(self._lines[#self._lines]) do
    width = width + vim.fn.strwidth(segment.str)
  end
  return width
end

function Text:trim()
  while #self._lines > 0 and #self._lines[#self._lines] == 0 do
    table.remove(self._lines)
  end
end

---@param buf number
---@param ns number
function Text:render(buf, ns)
  local lines = {}

  for _, line in ipairs(self._lines) do
    local str = string.rep(" ", self.padding)
    for _, segment in ipairs(line) do
      str = str .. segment.str
    end
    if str:match("^%s*$") then
      str = ""
    end
    table.insert(lines, str)
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  for l, line in ipairs(self._lines) do
    if lines[l] ~= "" or true then -- process even empty lines for extmarks
      local col = self.padding
      for _, segment in ipairs(line) do
        local width = vim.fn.strwidth(segment.str)
        local extmark = segment.hl

        if extmark then
          if type(extmark) == "string" then
            -- Simple highlight group string
            if width > 0 then
              pcall(vim.api.nvim_buf_set_extmark, buf, ns, l - 1, col, {
                hl_group = extmark,
                end_col = col + width,
              })
            end
          elseif type(extmark) == "table" then
            -- Full extmark table (virt_text, etc.)
            local extmark_col = extmark.col or col
            local opts = vim.tbl_extend("force", {}, extmark)
            opts.col = nil -- col is positional, not an extmark option
            if not opts.end_col and width > 0 and opts.hl_group then
              opts.end_col = extmark_col + width
            end
            pcall(vim.api.nvim_buf_set_extmark, buf, ns, l - 1, extmark_col, opts)
          end
        end
        col = col + width
      end
    end
  end
end

M.Text = Text

return M
