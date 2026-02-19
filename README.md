# glaze.nvim 󱓞

> A **Mason/Lazy-style** interface for managing Go binaries across Neovim plugins.
> Charmbracelet-inspired aesthetic. Zero duplication. One source of truth.

![Lua](https://img.shields.io/badge/Lua-2C2D72?style=flat&logo=lua&logoColor=white)
![Neovim](https://img.shields.io/badge/Neovim%200.9+-57A143?style=flat&logo=neovim&logoColor=white)

## ✨ Features

- **Centralized binary management** — Register binaries from any plugin, update them all at once
- **Lazy.nvim-style UI** — Floating window with progress bars, spinners, and status indicators  
- **Parallel installations** — Configurable concurrency for fast updates
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

### Keybinds (in Glaze UI)

| Key | Action |
|-----|--------|
| `u` | Update all binaries |
| `i` | Install missing binaries |
| `x` | Abort running tasks |
| `q` / `<Esc>` | Close window |

## 🔌 For Plugin Authors

Register your plugin's binaries as a dependency:

```lua
-- In your plugin's setup or init:
local ok, glaze = pcall(require, "glaze")
if ok then
  glaze.register("mytool", "github.com/me/mytool", {
    plugin = "myplugin.nvim",  -- Shows in UI
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
  local glaze = require("glaze")
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
glaze.is_installed(name)          -- Check if binary exists
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
```

## 🤝 Related Projects

- [freeze.nvim](https://github.com/taigrr/freeze.nvim) — Screenshot code with freeze
- [neocrush.nvim](https://github.com/taigrr/neocrush.nvim) — AI-powered coding assistant
- [lazy.nvim](https://github.com/folke/lazy.nvim) — UI inspiration
- [mason.nvim](https://github.com/williamboman/mason.nvim) — Concept inspiration

## 📄 License

MIT
