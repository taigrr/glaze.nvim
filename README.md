# 🍩 glaze.nvim

> **Go + Lazy = Glaze** — A Mason/Lazy-style manager for Go binaries in Neovim.
> Charmbracelet-inspired aesthetic. Zero duplication. One source of truth.
>
> *Like a fresh doughnut glaze — smooth, sweet, and holds everything together.*

![Lua](https://img.shields.io/badge/Lua-2C2D72?style=flat&logo=lua&logoColor=white)
![Neovim](https://img.shields.io/badge/Neovim%200.9+-57A143?style=flat&logo=neovim&logoColor=white)
![Go Required](https://img.shields.io/badge/Go-required-00ADD8?style=flat&logo=go&logoColor=white)
![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)

## 🤔 Why Glaze?

Every Go-based Neovim plugin reinvents the wheel: each one ships its own
`go install` wrapper, its own update command, its own version checking.

**Glaze stops the madness.** Register your binaries once, manage them all from
one beautiful UI. Plugin authors get a two-line integration. Users get a single
`:Glaze` command.

## ✨ Features

- **Centralized binary management** — Register binaries from any plugin, update them all at once
- **Lazy.nvim-style UI** — Floating window with progress bars, spinners, and status indicators
- **Cursor-aware keybinds** — `u` updates the binary under your cursor, `U` updates all
- **Parallel installations** — Configurable concurrency for fast updates
- **Auto-update checking** — Daily/weekly checks with non-intrusive notifications
- **GOBIN/GOPATH awareness** — Finds binaries even if not in PATH
- **Detail expansion** — Press `<CR>` to see URL, install path, version info
- **Charmbracelet aesthetic** — Pink/magenta color scheme that matches the Charm toolchain
- **Zero config for dependents** — Just register and go
- **Callback support** — Get notified when your binary is updated

## 📦 Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "taigrr/glaze.nvim",
  config = function()
    require("glaze").setup({})
  end,
}
```

## 🚀 Quick Start

```lua
local glaze = require("glaze")

-- Setup (usually in your plugin config)
glaze.setup({})

-- Register binaries
glaze.register("freeze", "github.com/charmbracelet/freeze")
glaze.register("glow", "github.com/charmbracelet/glow")
glaze.register("mods", "github.com/charmbracelet/mods")
```

## 📖 Usage

### Commands

| Command | Description |
|---------|-------------|
| `:Glaze` | Open the Glaze UI |
| `:GlazeUpdate [name]` | Update all or specific binary |
| `:GlazeInstall [name]` | Install missing or specific binary |
| `:GlazeCheck` | Manually check for available updates |

### Keybinds (in Glaze UI)

| Key | Action |
|-----|--------|
| `U` | Update ALL binaries |
| `u` | Update binary under cursor |
| `I` | Install all missing binaries |
| `i` | Install binary under cursor |
| `x` | Abort running tasks |
| `<CR>` | Toggle details (URL, path, version) |
| `q` / `<Esc>` | Close window |

## 🔌 For Plugin Authors

Register your plugin's binaries as a dependency — two lines is all it takes:

```lua
-- In your plugin's setup or init:
local ok, glaze = pcall(require, "glaze")
if ok then
  glaze.register("mytool", "github.com/me/mytool", {
    plugin = "myplugin.nvim",
    callback = function(success)
      if success then
        vim.notify("mytool updated!")
      end
    end,
  })
end
```

### Providing Update Commands

You can still expose plugin-specific commands that delegate to Glaze:

```lua
vim.api.nvim_create_user_command("MyPluginUpdate", function()
  require("glaze.runner").update({ "mytool" })
end, {})
```

## ⚙️ Configuration

```lua
require("glaze").setup({
  ui = {
    border = "rounded",  -- "none", "single", "double", "rounded", "solid", "shadow"
    size = { width = 0.7, height = 0.8 },  -- Percentage of screen
    icons = {
      pending = "○",
      running = "◐",
      done = "●",
      error = "✗",
      binary = "󰆍",
    },
  },
  concurrency = 4,  -- Max parallel installations
  go_cmd = { "go" },  -- Auto-detects goenv if available
  auto_install = {
    enabled = true,      -- Auto-install missing binaries on register
    silent = false,      -- Suppress install notifications
  },
  auto_check = {
    enabled = true,      -- Auto-check for updates
    frequency = "daily", -- "daily", "weekly", or hours as number
  },
})
```

## 🎨 Highlight Groups

Glaze defines these highlight groups (all prefixed with `Glaze`):

| Group | Description |
|-------|-------------|
| `GlazeH1` | Main title (pink) |
| `GlazeH2` | Section headers |
| `GlazeBinary` | Binary names |
| `GlazeUrl` | Module URLs |
| `GlazePlugin` | Plugin names |
| `GlazeDone` | Success status |
| `GlazeError` | Error status |
| `GlazeRunning` | In-progress status |
| `GlazeProgressDone` | Progress bar (filled) |
| `GlazeProgressTodo` | Progress bar (empty) |

## 📋 API

```lua
local glaze = require("glaze")

-- Registration
glaze.register(name, url, opts?)  -- Register a binary
glaze.unregister(name)            -- Remove a binary
glaze.binaries()                  -- Get all registered binaries

-- Status
glaze.is_installed(name)          -- Check if binary exists (PATH + GOBIN + GOPATH)
glaze.bin_path(name)              -- Get full path to binary
glaze.status(name)                -- "installed", "missing", or "unknown"

-- Runner (for programmatic control)
local runner = require("glaze.runner")
runner.update({ "freeze", "glow" })  -- Update specific binaries
runner.update_all()                  -- Update all
runner.install({ "freeze" })         -- Install specific
runner.install_missing()             -- Install all missing
runner.abort()                       -- Stop all tasks
runner.is_running()                  -- Check if tasks are running
runner.tasks()                       -- Get current task list
runner.stats()                       -- Get { total, done, error, running, pending }

-- Update checker
local checker = require("glaze.checker")
checker.check()                      -- Check for updates (with notifications)
checker.auto_check()                 -- Check only if enough time has passed
checker.get_update_info()            -- Get cached update info
```

## 🤝 Related Projects

- [freeze.nvim](https://github.com/taigrr/freeze.nvim) — Screenshot code with freeze
- [neocrush.nvim](https://github.com/taigrr/neocrush.nvim) — AI-powered coding assistant
- [blast.nvim](https://github.com/taigrr/blast.nvim) — Code activity tracking
- [lazy.nvim](https://github.com/folke/lazy.nvim) — UI inspiration
- [mason.nvim](https://github.com/williamboman/mason.nvim) — Concept inspiration

## 📄 License

MIT © [Tai Groot](https://github.com/taigrr)
