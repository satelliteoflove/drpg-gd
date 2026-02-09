# DRPG-GD

A Wizardry-style first-person dungeon crawler built in Godot 4.6 with GDScript.

## What Is This

A classic dungeon RPG inspired by Wizardry and its descendants. You create a party of adventurers, descend into procedurally generated dungeons, fight turn-based battles, and manage your crew back in town.

Many features are not yet implemented, but you're welcome to play around with it if you like. This serves as a primary test bed for my [Godot MCP server](https://github.com/satelliteoflove/godot-mcp).

## Requirements

- [Godot Engine 4.6](https://godotengine.org/download/) (Forward+ renderer)
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

3. Open the project in Godot 4.6

4. Hit Play (F5)

5. Go to Training Grounds to create characters, then Tavern to add them to your party, then head into the dungeon

## Controls

Mouse support is enabled for the town and most combat/dungeon menus.

All keyboard bindings are configurable via Project > Project Settings > Input Map in the Godot editor. The default bindings use a vim-style layout (hjkl + arrow keys) but can be changed to whatever you prefer.

In the dungeon, you can move forward/backward, turn left/right, and strafe. There are bindings to open the map, party menu, and inventory.

Town and combat use standard menu navigation: directional movement, confirm, cancel, and a select/multi-select action for batch operations in the shop.

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
