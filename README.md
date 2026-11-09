# DRPG-GD

A Wizardry-style first-person dungeon crawler built in Godot 4.7 with GDScript.

## What Is This

A classic dungeon RPG inspired by Wizardry and its descendants. You lead a guild of adventurers down through eight procedurally generated floors, fight turn-based battles, and manage your crew back in town. Guardians wait on floors 2, 4 and 6, and the stairs down stay sealed until each one falls. Slaying Vrakthorne the Drake on floor 8 wins the game, and the guild can keep delving afterward.

Time runs faster the deeper you go. A day on floor 1 is a day, but a few days on the lower floors can cost your adventurers years, and only the ones you send down age. Veterans and elders trade body for skill, and can retire to a post in town and train an apprentice. See [docs/deep-time.md](docs/deep-time.md).

Many features are not yet implemented, but you're welcome to play around with it if you like. This serves as a primary test bed for my [Godot MCP server](https://github.com/satelliteoflove/godot-mcp).

## Requirements

- [Godot Engine 4.7](https://godotengine.org/download/) (Forward+ renderer)
- [Git LFS](https://git-lfs.com/) (textures are stored with LFS)

## Getting Started

1. Install Git LFS if you haven't already:
   ```
   git lfs install
   ```

2. Clone the repo:
   ```
   git clone git@github.com:satelliteoflove/drpg-gd.git
   ```

3. Open the project in Godot 4.7

4. Hit Play (F5)

5. Start a new game. Your first six adventurers are already in the party, so you can head straight into the dungeon. The Guild Hall takes on new recruits when you need them.

## Controls

Mouse support is enabled for the town and most combat/dungeon menus.

All keyboard bindings are configurable via Project > Project Settings > Input Map in the Godot editor. The default bindings use a vim-style layout (hjkl + arrow keys) but can be changed to whatever you prefer.

In the dungeon, you can move forward/backward, turn left/right, and strafe. There are bindings to open the map, party menu, and inventory.

Town and combat use standard menu navigation: directional movement, confirm, cancel, and a select/multi-select action for batch operations in the shop.

Pressing T in the dungeon crushes a Recall Stone and returns the party to town. New games start with two, and the shop sells more. Walking out up the floor 1 stairs is always free.

## AI Dialogue (optional)

Party banter can be written by a small local language model. It's off by default; turn it on with "AI Dialogue" on the title screen. The first time, the game downloads a llama.cpp server and a model of about 3 GB. With it off, the game uses written lines.

## Debug Builds

Running from the editor (or any debug export) enables developer shortcuts: instant-win in combat, gold and keys, floor teleport, map reveal, AutoExplore in town, and so on. Release exports leave all of these out.

## Project Structure

```
autoload/       Global singletons (GameState, SaveManager, etc.)
data/           Static game data (items, spells, monsters)
resources/      Resource class definitions
scenes/         Scene files and their scripts
systems/        Core game systems (combat, dungeon, magic)
textures/       Texture assets (Git LFS)
tests/          Unit and integration tests
```
