# DRPG-GD Development Guide

## Godot + Claude Code Workflow

### Game Session Management

Prefer reusing running game sessions over stopping/restarting:
- Many code changes hot-reload without requiring a restart
- Only restart when: adding new autoloads, changing project settings, or after crashes
- Use screenshots to verify state rather than restarting to "check if it worked"
- If unsure whether a change requires restart, try it first - worst case is a crash

### Handling Crashes Gracefully

When the game crashes or errors occur:
- Check editor debug output for error messages before restarting
- Note the error for context in case it recurs
- Restart the game and continue testing
- Don't treat crashes as blockers - they're normal during development

### Script Hot-Reload

To enable automatic script reloading (recommended):
1. Open Godot Editor
2. Go to Editor > Editor Settings
3. Navigate to Text Editor > Behavior > Files
4. Enable "Auto Reload Scripts On External Change" (checkbox)
5. Also enable "Auto Reload And Parse Scripts On Save"

This eliminates the modal dialog when scripts are modified externally.
Note: Reload only triggers when the Godot editor window gains focus.

### Testing Workflow

1. Keep the game running during iterative changes
2. Use the map screen debug buttons (R, E, Z, N) for quick state inspection
3. Use Quick Start for fast dungeon entry
4. Only restart when necessary

### Python Scripts

Always use `uv run --with <package>` to run Python scripts. Never use `pip install` directly.
Example: `uv run --with Pillow python3 script.py`

## Project Structure

### Key Directories
- `autoload/` - Global singletons (GameState, SaveManager, etc.)
- `data/` - Static game data (items, spells, monsters)
- `resources/` - Resource class definitions
- `scenes/` - Scene files and their scripts
- `systems/` - Core game systems (combat, dungeon, magic)

### Dungeon System
- `dungeon_generator.gd` - Procedural dungeon generation
- `enemy_manager.gd` - Enemy spawning and AI coordination
- `enemy_ai.gd` - Individual enemy behavior decisions
- `pathfinding.gd` - A* pathfinding for enemies
- `floor_tracker.gd` - Global step counter, spotted enemies, reveal state

### Movement Keybindings (vim-style)
- k/Up - Move forward
- j/Down - Move backward
- h/Left - Turn left
- l/Right - Turn right
- Shift+h - Strafe left
- Shift+l - Strafe right

### Dungeon Debug Keys
- G - Add gold
- C - Force combat encounter
- Shift+F - Teleport to next floor (at stairs up)
- Ctrl+F - Teleport to previous floor (at stairs up)

### Map Screen Debug Keys
- R - Reveal entire map
- E - Show/hide all enemies
- Z - Show/hide encounter zones
- N/Esc - Close map
