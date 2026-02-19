# glaze.nvim Demo
# Records the main UI and update flow
#
# Requirements:
#   - vhs (brew install vhs)
#   - nvim >= 0.9
#   - go installed
#
# Run: vhs docs/demo.tape

Output docs/demo.gif

Require nvim
Require go

Set Shell bash
Set FontSize 14
Set Width 1000
Set Height 600
Set Theme "Catppuccin Mocha"
Set WindowBar Colorful
Set Padding 15
Set TypingSpeed 30ms
Set CursorBlink false

# Hidden setup - isolate config and set up environment
Hide
Type "export XDG_CONFIG_HOME=/tmp/vhs-glaze-config"
Enter
Type "export XDG_DATA_HOME=/tmp/vhs-glaze-data"
Enter
Type "mkdir -p /tmp/vhs-glaze-config /tmp/vhs-glaze-data /tmp/glaze-demo && cd /tmp/glaze-demo"
Enter
Sleep 200ms

# Create empty file to open
Type "touch demo.lua"
Enter
Sleep 200ms
Type "clear"
Enter
Sleep 200ms

# Start nvim with minimal config (PLUGIN_PATH set by Makefile or manually)
Type `nvim --clean -u $PLUGIN_PATH/scripts/vhs_init.lua --cmd "set rtp+=$PLUGIN_PATH" demo.lua`
Enter
Sleep 2s

Show

# Open Glaze UI
Type ":Glaze"
Enter
Sleep 2s

# Let the UI fully render before navigating
Sleep 500ms

# Navigate down through binaries
Type "j"
Sleep 300ms
Type "j"
Sleep 300ms

# Expand details on current binary
Enter
Sleep 1.2s

# Collapse details
Enter
Sleep 600ms

# Update ALL binaries with U
Type "U"
Sleep 10s

# Show the completed state
Sleep 2s

# Close and quit
Hide
Type "q"
Sleep 300ms
Type ":qa!"
Enter
Sleep 300ms
