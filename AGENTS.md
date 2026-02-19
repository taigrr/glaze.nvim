# AGENTS.md

AI agent guide for working in glaze.nvim.

## Project Overview

**glaze.nvim** is a Neovim plugin that provides centralized management for Go binaries used by other Neovim plugins. Think "Mason for Go binaries" with a lazy.nvim-style UI.

- **Language**: Lua (Neovim plugin)
- **Requirements**: Neovim >= 0.9, Go installed
- **Author**: Tai Groot (taigrr)

## Directory Structure

```
lua/glaze/
├── init.lua      # Main module: setup, config, registration API, binary path utilities
├── runner.lua    # Task runner: parallel go install with concurrency control
├── checker.lua   # Update checker: version comparison, auto-check scheduling
├── view.lua      # UI: lazy.nvim-style floating window, keybinds, rendering
├── float.lua     # Float window abstraction: backdrop, keymaps, resize handling
├── text.lua      # Text rendering: buffered text with highlight segments
├── colors.lua    # Highlight definitions: doughnut-inspired pink/magenta theme
├── health.lua    # Health check: :checkhealth glaze
doc/
└── glaze.txt     # Vim help documentation
```

## Key Concepts

### Binary Registration

Plugins register binaries via `require("glaze").register(name, url, opts)`. Registration stores metadata in `M._binaries` table. Auto-install triggers if enabled and binary is missing.

### Task Runner

`runner.lua` manages parallel `go install` jobs with configurable concurrency. Tasks have states: `pending → running → done|error`. The runner opens the UI automatically when tasks start.

### Update Checking

`checker.lua` compares installed versions (`go version -m`) against latest (`go list -m -json`). State persisted to `vim.fn.stdpath("data") .. "/glaze/state.json"`.

### UI Architecture

- `float.lua`: Generic floating window with backdrop (inspired by lazy.nvim)
- `view.lua`: Glaze-specific rendering, keybinds, spinner animation
- `text.lua`: Buffered text builder with highlight segments and extmarks

## Commands

| Command                | Description                        |
| ---------------------- | ---------------------------------- |
| `:Glaze`               | Open the UI                        |
| `:GlazeUpdate [name]`  | Update all or specific binary      |
| `:GlazeInstall [name]` | Install missing or specific binary |
| `:GlazeCheck`          | Manual update check                |
| `:checkhealth glaze`   | Run health check                   |

## Testing

**No automated tests exist.** Manual testing workflow:

```lua
-- In Neovim:
:luafile %              -- Reload current file
:Glaze                  -- Test UI
:checkhealth glaze      -- Verify setup
```

Test with actual binaries:

```lua
require("glaze").setup({})
require("glaze").register("glow", "github.com/charmbracelet/glow")
:GlazeInstall glow
```

## Code Conventions

### Module Pattern

All modules return a table `M` with public functions. Private functions prefixed with `_`:

```lua
local M = {}
M._private_state = {}
function M.public_fn() end
function M._private_fn() end
return M
```

### Type Annotations

Uses LuaCATS (`---@class`, `---@param`, `---@return`) for type hints. LSP warnings about `vim` being undefined are expected (Neovim globals).

### Async Patterns

- `vim.fn.jobstart()` for external commands
- `vim.schedule()` to defer to main loop
- `vim.defer_fn()` for delayed execution

### UI Updates

- Runner notifies via `M._on_update` callback
- View subscribes and re-renders on notification
- Timer drives spinner animation (100ms interval)

## Highlight Groups

All highlights prefixed with `Glaze`. Key groups:

- `GlazeH1`, `GlazeH2` - Headers
- `GlazeBinary`, `GlazeUrl`, `GlazePlugin` - Content
- `GlazeDone`, `GlazeError`, `GlazeRunning` - Status
- `GlazeProgressDone`, `GlazeProgressTodo` - Progress bar

Colors follow doughnut aesthetic (pink `#FF6AD5` as primary accent).

## Configuration

Default config in `init.lua:53-78`. Key options:

- `concurrency`: Parallel jobs (default 4)
- `auto_install.enabled`: Install on register
- `auto_check.enabled/frequency`: Update checking
- `auto_update.enabled`: Auto-apply updates

## Common Tasks

### Adding a New Config Option

1. Add to `GlazeConfig` type definition in `init.lua`
2. Add default value in `M.config`
3. Document in `README.md` and `doc/glaze.txt`

### Adding a New Command

1. Create in `M.setup()` via `vim.api.nvim_create_user_command()`
2. Document in README and help file

### Modifying UI

1. Edit `view.lua:render()` for content changes
2. Edit `view.lua:open()` to add keybinds
3. Edit `colors.lua` for new highlight groups

### Adding Health Checks

Add checks in `health.lua:check()` using `vim.health.ok/warn/error/info`.

## Gotchas

1. **vim global**: All `vim.*` calls show LSP warnings - this is normal for Neovim plugins without proper Lua LSP config.

2. **Race conditions**: `runner.lua` rejects new tasks if already running. Check `runner.is_running()` first.

3. **Timer cleanup**: `view.lua._timer` must be stopped on close, or spinner keeps running.

4. **State file**: `checker.lua` persists to data dir. If corrupt, delete `~/.local/share/nvim/glaze/state.json`.

5. **GOBIN detection**: Checks multiple locations: `$GOBIN`, `$GOPATH/bin`, `~/go/bin`. See `init.lua:is_installed()`.

6. **goenv support**: Auto-detected in setup, changes `go_cmd` to `{ "goenv", "exec", "go" }`.

## API Reference

Main module (`require("glaze")`):

- `setup(opts)` - Initialize with config
- `register(name, url, opts)` - Register binary
- `unregister(name)` - Remove binary
- `binaries()` - Get all registered
- `is_installed(name)` - Check if binary exists
- `bin_path(name)` - Get full path
- `status(name)` - Get "installed"/"missing"/"unknown"

Runner (`require("glaze.runner")`):

- `update(names)` / `update_all()` - Update binaries
- `install(names)` / `install_missing()` - Install binaries
- `abort()` - Stop all tasks
- `is_running()` / `tasks()` / `stats()` - Query state

Checker (`require("glaze.checker")`):

- `check(opts)` - Check for updates
- `auto_check()` - Check if interval passed
- `get_update_info()` - Get cached version info
