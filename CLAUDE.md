# DRPG-GD Development Guide

## Godot + Claude Code Workflow

### Game Session Management

Prefer reusing running game sessions over stopping/restarting:
- Many code changes hot-reload without requiring a restart
- Only restart when: adding new autoloads, changing project settings, or after crashes
- Verify state by reading runtime state or screenshots rather than restarting to "check if it worked" (see **Screenshots & Game Observation** below — prefer text introspection)
- If unsure whether a change requires restart, try it first - worst case is a crash
- For playtests that don't need LLM dialogue, start the editor with `DRPG_DISABLE_LLM=1` in its environment (the game inherits it). The game then never starts llama-server, even on a machine that has the model and so counts as opted in to AI dialogue, and dialogue uses its written fallbacks. Stopping the game from the editor force-kills it, so a llama-server it started stays running until the next launch cleans it up.

### Running the editor without a desktop

`tools/background_editor.sh <godot binary>` starts the editor inside a headless sway compositor, so godot-mcp works with nobody logged in to the desktop. It renders in software (llvmpipe): fine for menus and UI checks, slow for the 3D dungeon, and the game takes 20 seconds or so to load. For tests and simulations no editor is needed: run Godot with `--headless` (see `tests/`).

### Screenshots & Game Observation

Screenshots compound in cost: any frame Claude views is inlined into context and **persists for the whole session with no decay** (~600–1,200 tokens each). A long visual session can drown in stale frames. So:

- **Prefer text introspection over pixels.** Structural/state questions (focused control, label text, HP/MP/gold, current scene, node visibility, player position/facing, enemy count) are answerable as cheap text via godot-mcp's `godot_runtime_state` / `godot_node_read` / `godot_scene3d`. Screenshot only for genuinely *visual* judgments (spacing, color, art, animation, legibility).
- **Take screenshots inline, sparingly.** Capture only when the question is visual, set up the state with `godot_exec` first so one frame answers it, and don't re-shoot a view that hasn't changed.
- **Default capture is ~640px** — a sensible baseline that keeps the common case cheap; request higher resolution when finer detail helps (alignment, small art, tiny text). It's a default, not a hard cap.

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

### Issue Tracking

Always use the GitHub issue tracker for bugs and feature requests that are not being resolved immediately. When the user flags an issue during playtesting or conversation that will not be fixed right now, create a GitHub issue for it. Do not rely on memory files for issue tracking.

### Suggesting Changes

When advising on fixes or adjustments, start with the most elegant (and usually simple) solution to the problem. Try to avoid unnecessary changes and technical debt.

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
- `floor_checker.gd` - Refuses a generated floor that can't be played (no way to the stairs, cut-off tiles, no reachable guardian); the generator retries from the next seed
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
Debug keys (here, on the map screen, and in combat) only work in debug builds, which includes running from the editor.
- T - Return to town (costs a Recall Stone; not a debug key)
- G - Add gold
- Shift+F - Teleport to next floor (at stairs up)
- Ctrl+F - Teleport to previous floor (at stairs up)

### Map Screen Debug Keys
- R - Reveal entire map
- E - Show/hide all enemies
- Z - Show/hide encounter zones
- N/Esc - Close map
