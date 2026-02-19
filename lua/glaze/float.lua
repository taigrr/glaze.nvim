---@brief [[
--- glaze.nvim floating window (based on lazy.nvim)
--- Creates centered floating window with backdrop
---@brief ]]

local M = {}

---@class GlazeFloatOptions
---@field size? { width: number, height: number }
---@field border? string
---@field title? string
---@field zindex? number

---@class GlazeFloat
---@field buf number
---@field win number
---@field opts GlazeFloatOptions
---@field win_opts table
---@field backdrop_buf? number
---@field backdrop_win? number
local Float = {}

local _id = 0

---@param opts? GlazeFloatOptions
---@return GlazeFloat
function Float.new(opts)
  local self = setmetatable({}, { __index = Float })
  return self:init(opts)
end

---@param opts? GlazeFloatOptions
function Float:init(opts)
  require("glaze.colors").setup()

  _id = _id + 1
  self.id = _id

  local config = require("glaze").config
  self.opts = vim.tbl_deep_extend("force", {
    size = config.ui.size,
    border = config.ui.border,
    zindex = 50,
  }, opts or {})

  self.win_opts = {
    relative = "editor",
    style = "minimal",
    border = self.opts.border,
    zindex = self.opts.zindex,
    title = self.opts.title,
    title_pos = self.opts.title and "center" or nil,
  }

  self:mount()
  return self
end

function Float:layout()
  local function size(max, value)
    return value > 1 and math.min(value, max) or math.floor(max * value)
  end

  self.win_opts.width = size(vim.o.columns, self.opts.size.width)
  self.win_opts.height = size(vim.o.lines - 4, self.opts.size.height)
  self.win_opts.row = math.floor((vim.o.lines - self.win_opts.height) / 2)
  self.win_opts.col = math.floor((vim.o.columns - self.win_opts.width) / 2)

  if self.opts.border ~= "none" then
    self.win_opts.row = self.win_opts.row - 1
    self.win_opts.col = self.win_opts.col - 1
  end
end

function Float:mount()
  self.buf = vim.api.nvim_create_buf(false, true)

  -- Create backdrop
  local normal = vim.api.nvim_get_hl(0, { name = "Normal" })
  if normal.bg and vim.o.termguicolors then
    self.backdrop_buf = vim.api.nvim_create_buf(false, true)
    self.backdrop_win = vim.api.nvim_open_win(self.backdrop_buf, false, {
      relative = "editor",
      width = vim.o.columns,
      height = vim.o.lines,
      row = 0,
      col = 0,
      style = "minimal",
      focusable = false,
      zindex = self.opts.zindex - 1,
    })
    vim.api.nvim_set_hl(0, "GlazeBackdrop", { bg = "#000000", default = true })
    vim.wo[self.backdrop_win].winhighlight = "Normal:GlazeBackdrop"
    vim.wo[self.backdrop_win].winblend = 60
    vim.bo[self.backdrop_buf].buftype = "nofile"
  end

  self:layout()
  self.win = vim.api.nvim_open_win(self.buf, true, self.win_opts)

  -- Buffer settings
  vim.bo[self.buf].buftype = "nofile"
  vim.bo[self.buf].bufhidden = "wipe"
  vim.bo[self.buf].filetype = "glaze"

  -- Window settings
  vim.wo[self.win].conceallevel = 3
  vim.wo[self.win].foldenable = false
  vim.wo[self.win].spell = false
  vim.wo[self.win].wrap = true
  vim.wo[self.win].winhighlight = "Normal:GlazeNormal,FloatBorder:GlazeBorder"
  vim.wo[self.win].cursorline = true

  -- Keymaps
  self:map("q", function()
    self:close()
  end, "Close")
  self:map("<Esc>", function()
    self:close()
  end, "Close")

  -- Auto-close on WinClosed — also trigger view cleanup to stop timer
  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(self.win),
    once = true,
    callback = function()
      -- Trigger view close to clean up timer
      local ok, view = pcall(require, "glaze.view")
      if ok then
        view.close()
      else
        self:close()
      end
    end,
  })

  -- Handle resize
  vim.api.nvim_create_autocmd("VimResized", {
    callback = function()
      if not self:valid() then
        return true
      end
      self:layout()
      vim.api.nvim_win_set_config(self.win, {
        relative = "editor",
        width = self.win_opts.width,
        height = self.win_opts.height,
        row = self.win_opts.row,
        col = self.win_opts.col,
      })
      if self.backdrop_win and vim.api.nvim_win_is_valid(self.backdrop_win) then
        vim.api.nvim_win_set_config(self.backdrop_win, {
          width = vim.o.columns,
          height = vim.o.lines,
        })
      end
    end,
  })
end

---@param key string
---@param fn function
---@param desc string
function Float:map(key, fn, desc)
  vim.keymap.set("n", key, fn, { buffer = self.buf, nowait = true, desc = desc })
end

function Float:valid()
  return self.win and vim.api.nvim_win_is_valid(self.win)
end

function Float:close()
  vim.schedule(function()
    if self.backdrop_win and vim.api.nvim_win_is_valid(self.backdrop_win) then
      vim.api.nvim_win_close(self.backdrop_win, true)
    end
    if self.backdrop_buf and vim.api.nvim_buf_is_valid(self.backdrop_buf) then
      vim.api.nvim_buf_delete(self.backdrop_buf, { force = true })
    end
    if self.win and vim.api.nvim_win_is_valid(self.win) then
      vim.api.nvim_win_close(self.win, true)
    end
    if self.buf and vim.api.nvim_buf_is_valid(self.buf) then
      vim.api.nvim_buf_delete(self.buf, { force = true })
    end
  end)
end

---@return number
function Float:width()
  return self.win_opts.width
end

M.Float = Float

return M
