<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://github.com/taigrr/glaze.nvim/raw/master/docs/glaze-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="https://github.com/taigrr/glaze.nvim/raw/master/docs/glaze-light.svg">
  <img alt="glaze.nvim" src="https://github.com/taigrr/glaze.nvim/raw/master/docs/glaze-dark.svg" width="400">
</picture>

<p>
  <a href="https://github.com/taigrr/glaze.nvim/releases/latest">
    <img alt="Latest release" src="https://img.shields.io/github/v/release/taigrr/glaze.nvim?style=for-the-badge&logo=starship&color=FF6AD5&logoColor=D9E0EE&labelColor=302D41&include_prerelease&sort=semver">
  </a>
  <a href="https://github.com/taigrr/glaze.nvim/pulse">
    <img alt="Last commit" src="https://img.shields.io/github/last-commit/taigrr/glaze.nvim?style=for-the-badge&logo=starship&color=8bd5ca&logoColor=D9E0EE&labelColor=302D41">
  </a>
  <a href="https://github.com/taigrr/glaze.nvim/blob/master/LICENSE">
    <img alt="License" src="https://img.shields.io/github/license/taigrr/glaze.nvim?style=for-the-badge&logo=starship&color=ee999f&logoColor=D9E0EE&labelColor=302D41">
  </a>
  <a href="https://github.com/taigrr/glaze.nvim/stargazers">
    <img alt="Stars" src="https://img.shields.io/github/stars/taigrr/glaze.nvim?style=for-the-badge&logo=starship&color=c69ff5&logoColor=D9E0EE&labelColor=302D41">
  </a>
</p>

**Go + Lazy = Glaze** — A centralized manager for Go binaries in Neovim.

<img alt="glaze.nvim demo" src="https://github.com/taigrr/glaze.nvim/raw/master/docs/demo.gif" width="700">

## The Problem

Every Go-based Neovim plugin reinvents the wheel:

- **freeze.nvim** needs `freeze` → ships its own installer
- **glow.nvim** needs `glow` → ships its own installer
- **mods.nvim** needs `mods` → ships its own installer

Each plugin implements `go install`, update checking, and version management from scratch.
Users run different update commands for each plugin. Plugin authors duplicate code.

## The Solution

**Glaze** provides a single source of truth for Go binaries:

```lua
-- Plugin authors: two lines
local ok, glaze = pcall(require, "glaze")
if ok then glaze.register("freeze", "github.com/charmbracelet/freeze") end

-- Users: one command
:Glaze
```

## ✨ Features

- 📦 **Centralized management** — Register binaries from any plugin, manage from one UI
- 🚀 **Parallel installations** — Configurable concurrency for fast updates
- 🎯 **Cursor-aware keybinds** — `u` updates binary under cursor, `U` updates all
- 🔄 **Auto-update checking** — Daily/weekly checks with non-intrusive notifications
- 📍 **Smart binary detection** — Finds binaries in PATH, GOBIN, and GOPATH
- 🎨 **Sugary-sweet aesthetic** — Pink/magenta theme reminding you of doughnuts...
- 🔔 **Callback support** — Get notified when your binary is updated
- ⚡ **Zero config for plugins** — Register and go

## 📦 Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "taigrr/glaze.nvim",
  config = function()
    require("glaze").setup()
  end,
}
```

### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "taigrr/glaze.nvim",
  config = function()
    require("glaze").setup()
  end,
}
```

## ⚡ Requirements

- Neovim >= **0.9.0**
- Go >= **1.18** (for `go install` support)
- Optional: [goenv](https://github.com/syndbg/goenv) (auto-detected)

## 🚀 Quick Start

```lua
local glaze = require("glaze")

-- Setup
glaze.setup()

-- Register binaries
glaze.register("freeze", "github.com/charmbracelet/freeze")
glaze.register("glow", "github.com/charmbracelet/glow")
glaze.register("gum", "github.com/charmbracelet/gum")

-- Open the UI
vim.cmd("Glaze")
```

## 📖 Commands

| Command                | Description                          |
| ---------------------- | ------------------------------------ |
| `:Glaze`               | Open the Glaze UI                    |
| `:GlazeUpdate [name]`  | Update all or specific binary        |
| `:GlazeInstall [name]` | Install missing or specific binary   |
| `:GlazeCheck`          | Manually check for available updates |

## ⌨️ Keybinds

| Key           | Action                       |
| ------------- | ---------------------------- |
| `U`           | Update all binaries          |
| `u`           | Update binary under cursor   |
| `I`           | Install all missing binaries |
| `i`           | Install binary under cursor  |
| `x`           | Abort running tasks          |
| `<CR>`        | Toggle details               |
| `q` / `<Esc>` | Close window                 |

## 🔌 For Plugin Authors

Make your plugin a Glaze consumer with two lines:

```lua
-- In your plugin's setup:
local ok, glaze = pcall(require, "glaze")
if ok then
  glaze.register("mytool", "github.com/me/mytool", {
    plugin = "myplugin.nvim",  -- Shows in UI
    callback = function(success)
      if success then vim.notify("mytool updated!") end
    end,
  })
end
```

### Example Consumers

These plugins use Glaze to manage their Go binaries:

- [**neocrush.nvim**](https://github.com/taigrr/neocrush.nvim) — AI-powered coding assistant
- [**freeze.nvim**](https://github.com/taigrr/freeze.nvim) — Screenshot code with freeze
- [**blast.nvim**](https://github.com/taigrr/blast.nvim) — Code activity tracking

## ⚙️ Configuration

```lua
require("glaze").setup({
  -- UI settings
  ui = {
    border = "rounded",  -- "none", "single", "double", "rounded", "solid", "shadow"
    size = { width = 0.7, height = 0.8 },
    icons = {
      pending = "○",
      running = "◐",
      done = "●",
      error = "✗",
      binary = "󰆍",
    },
    use_system_theming = false,  -- Use nvim theme instead of doughnut colors
  },

  -- Parallel installations
  concurrency = 4,

  -- Go command (auto-detects goenv)
  go_cmd = { "go" },

  -- Auto-install missing binaries on register
  auto_install = {
    enabled = true,
    silent = false,
  },

  -- Auto-check for updates
  auto_check = {
    enabled = true,
    frequency = "daily",  -- "daily", "weekly", or hours as number
  },

  -- Auto-update when newer versions found
  auto_update = {
    enabled = false,  -- Requires auto_check
  },
})
```

## 📋 API

```lua
local glaze = require("glaze")

-- Registration
glaze.register(name, url, opts?)  -- Register a binary
glaze.unregister(name)            -- Remove a binary
glaze.binaries()                  -- Get all registered binaries

-- Status
glaze.is_installed(name)          -- Check if binary exists
glaze.bin_path(name)              -- Get full path to binary
glaze.status(name)                -- "installed", "missing", or "unknown"

-- Runner
local runner = require("glaze.runner")
runner.update({ "freeze" })       -- Update specific binaries
runner.update_all()               -- Update all
runner.install_missing()          -- Install all missing
runner.abort()                    -- Stop all tasks

-- Checker
local checker = require("glaze.checker")
checker.check()                   -- Check for updates
checker.get_update_info()         -- Get cached update info
```

## 🎨 Highlight Groups

| Group               | Description           |
| ------------------- | --------------------- |
| `GlazeH1`           | Main title            |
| `GlazeH2`           | Section headers       |
| `GlazeBinary`       | Binary names          |
| `GlazeUrl`          | Module URLs           |
| `GlazePlugin`       | Plugin names          |
| `GlazeDone`         | Success status        |
| `GlazeError`        | Error status          |
| `GlazeRunning`      | In-progress status    |
| `GlazeProgressDone` | Progress bar (filled) |
| `GlazeProgressTodo` | Progress bar (empty)  |

## 🩺 Health Check

```vim
:checkhealth glaze
```

Verifies Go installation, GOBIN configuration, and registered binary status.

## 🤝 Related Projects

Glaze is inspired by:

- [lazy.nvim](https://github.com/folke/lazy.nvim) — UI patterns and aesthetics
- [mason.nvim](https://github.com/williamboman/mason.nvim) — Centralized tool management concept

## 📄 License

[0BSD](LICENSE) © [Tai Groot](https://github.com/taigrr)
