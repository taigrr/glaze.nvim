---@brief [[
--- glaze.nvim health check
--- Run with :checkhealth glaze
---@brief ]]

local M = {}

function M.check()
  vim.health.start("glaze.nvim")

  -- Check Neovim version
  if vim.fn.has("nvim-0.9") == 1 then
    vim.health.ok("Neovim >= 0.9")
  else
    vim.health.error("Neovim >= 0.9 required", { "Upgrade Neovim to 0.9 or later" })
  end

  -- Check Go (required)
  if vim.fn.executable("go") == 1 then
    local go_version = vim.fn.system("go version"):gsub("%s+$", "")
    vim.health.ok(go_version)
  elseif vim.fn.executable("goenv") == 1 then
    local go_version = vim.fn.system("goenv exec go version 2>/dev/null"):gsub("%s+$", "")
    if go_version ~= "" and not go_version:match("not found") then
      vim.health.ok(go_version .. " (via goenv)")
    else
      vim.health.error("goenv found but no Go version installed", {
        "Run: goenv install <version>",
        "Or install Go directly: https://go.dev/dl/",
      })
    end
  else
    vim.health.error("Go not found", {
      "Go is required for installing and updating binaries",
      "Install from: https://go.dev/dl/",
    })
  end

  -- Check GOBIN / GOPATH
  local gobin = vim.env.GOBIN
  if not gobin or gobin == "" then
    local gopath = vim.env.GOPATH
    if gopath and gopath ~= "" then
      gobin = gopath .. "/bin"
    else
      gobin = vim.env.HOME .. "/go/bin"
    end
  end

  if vim.fn.isdirectory(gobin) == 1 then
    -- Check if GOBIN is in PATH
    local path = vim.env.PATH or ""
    if path:find(gobin, 1, true) then
      vim.health.ok("GOBIN in PATH: " .. gobin)
    else
      vim.health.warn("GOBIN exists but is not in PATH: " .. gobin, {
        "Add to PATH: export PATH=\"" .. gobin .. ":$PATH\"",
        "Binaries installed by Glaze may not be found without this",
      })
    end
  else
    vim.health.info("GOBIN directory does not exist yet: " .. gobin)
  end

  -- Check registered binaries
  local glaze = require("glaze")
  local binaries = glaze.binaries()
  local count = vim.tbl_count(binaries)

  if count == 0 then
    vim.health.info("No binaries registered (plugins will register on setup)")
  else
    vim.health.ok(count .. " binary(ies) registered")
    for name, binary in pairs(binaries) do
      if glaze.is_installed(name) then
        vim.health.ok("  " .. name .. " — installed" .. (binary.plugin and (" (" .. binary.plugin .. ")") or ""))
      else
        vim.health.warn("  " .. name .. " — missing" .. (binary.plugin and (" (" .. binary.plugin .. ")") or ""), {
          "Run :GlazeInstall " .. name,
          "Or: go install " .. binary.url .. "@latest",
        })
      end
    end
  end
end

return M
