# DRPG-GD Development Guide

## Godot + Claude Code Workflow

### Game Session Management

Prefer reusing running game sessions over stopping/restarting:
- Many code changes hot-reload without requiring a restart
- Only restart when: adding new autoloads, changing project settings, or after crashes
- Verify state by reading runtime state or screenshots rather than restarting to "check if it worked" (see **Screenshots & Game Observation** below — prefer text introspection and the game-observer sub-agent)
- If unsure whether a change requires restart, try it first - worst case is a crash

### Screenshots & Game Observation

Screenshots compound in cost: any frame Claude views is inlined into context and **persists for the whole session with no decay** (~600–1,200 tokens each). A long visual session can drown in stale frames. So:

- **Prefer text introspection over pixels.** Structural/state questions (focused control, label text, HP/MP/gold, current scene, node visibility, player position/facing, enemy count) are answerable as cheap text via godot-mcp's `godot_runtime_state` / `godot_node_read` / `godot_scene3d`. Screenshot only for genuinely *visual* judgments (spacing, color, art, animation, legibility).
- **Isolate screenshot-heavy work in the `game-observer` sub-agent** (`.claude/agents/game-observer.md`). For any multi-frame or screenshot-driven verification — UI, combat, dungeon navigation, anything — dispatch game-observer. It drives the game (optional freeze + input sequence + captures), interprets the frames, and returns a **text** verdict; the frames die with its discarded context instead of bloating the main session. Reserve inline screenshots in the main loop for frames the **user** needs to see (those are the deliverable).
- **Default capture is ~640px** — a sensible baseline that keeps the common case cheap; request higher resolution when finer detail helps (alignment, small art, tiny text). It's a default, not a hard cap.
- game-observer is **read-only** (prompt-enforced). If a check needs game-state setup it can't reach read-only (spawn enemies, force a dungeon state), that's the trigger to add a separate *setup-capable* observer — split on the permission boundary, not by domain.

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
- Shift+F - Teleport to next floor (at stairs up)
- Ctrl+F - Teleport to previous floor (at stairs up)

### Map Screen Debug Keys
- R - Reveal entire map
- E - Show/hide all enemies
- Z - Show/hide encounter zones
- N/Esc - Close map
