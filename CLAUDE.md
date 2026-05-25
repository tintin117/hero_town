# Hero Town — Claude Code Context

## Project Identity

Recreating **Crusaders Quest: Hero Town** (idle RPG town builder) in Godot 4.5.
- Steam page: https://store.steampowered.com/app/4126220/Crusaders_Quest__Hero_Town/
- Wiki: https://crusadersquestherotown.wiki/
- Genre: Idle RPG + Town Building, pixel art style
- Core appeal: heroes fight autonomously while the player manages a small town

## Tech Stack

- Godot 4.5, Forward Plus renderer, Jolt Physics, D3D12 (Windows)
- GDScript only
- Godot AI MCP plugin (`addons/godot_ai`) — enables Claude Code to read/write scenes and scripts directly via the editor

## File Structure

```
scenes/
  main.tscn       — root scene (1152×648 viewport)
  hero.tscn       — player hero CharacterBody2D
  enemy.tscn      — enemy CharacterBody2D
  building.tscn   — placeable building Node2D
scripts/
  main.gd         — game manager: gold, spawning, building placement, save/load
  hero.gd         — hero AI: PATROL → CHASE → ATTACK state machine
  enemy.gd        — enemy AI: walk toward hero, attack on range
  building.gd     — building data + click signal
  health_bar.gd   — drawn health bar (Node2D using _draw)
  grid_overlay.gd — tile grid drawn during placement mode
addons/godot_ai/  — MCP plugin, do not modify
```

## Key Constants

| Constant | Value | Location |
|---|---|---|
| `TILE_SIZE` | 64 px | main.gd, grid_overlay.gd |
| `GROUND_Y` | 900.0 | main.gd (hero/enemy walk line) |
| `GROUND_Y` | 400.0 | grid_overlay.gd (building strip top) |
| Viewport | 1152 × 648 | main.tscn Background node |

> Note: `GROUND_Y` differs between files intentionally — the overlay draws the placement strip higher up.

## What Is Implemented (Phase 1 + 2)

- One hero auto-patrols left/right, detects enemies via `Area2D`, chases and attacks
- Enemies spawn from the right edge every 3 s, walk toward the hero, attack on contact
- Hero and enemy both have drawn health bars (color-coded: green → yellow → red)
- Enemy death emits `died(gold_reward)` signal → gold added to UI counter
- Building placement: click "House 30g" → ghost appears, left-click to place, right-click/ESC cancels
- Buildings snap to a tile grid (X only; Y is always ground level)
- Multi-cell footprint support (`BUILDING_FOOTPRINTS` dict in main.gd)
- Placed buildings can be picked up and moved by clicking them
- Buildings save/load to `user://buildings.sav` (JSON)
- Gold balance displayed top-left; build button disables when insufficient gold

## Core Game Loop (target)

1. Heroes auto-patrol and fight waves of monsters
2. Defeating enemies yields gold and equipment drops
3. Player spends gold to upgrade buildings
4. Buildings improve hero stats / capacity / resources
5. Stronger heroes fight harder enemies → repeat

## Hero Classes (planned)

Warrior, Paladin, Hunter, Archer, Wizard, Priest

## Development Philosophy

- **Build in phases** — get the simplest version working first, then layer features
- **No premature abstraction** — three similar lines beats a helper no one needs yet
- **No speculative features** — only implement what the current phase requires

## Working with the Godot AI MCP Plugin

The plugin runs an MCP server inside the Godot editor. Claude Code connects to it to:
- Read/write `.tscn` and `.gd` files via `filesystem_manage`
- Inspect and modify scene nodes via `scene_manage`, `node_create`, `node_set_property`
- Attach scripts via `script_attach`
- Save scenes via `scene_save`
- Run the project via `project_run`
- Read editor/game logs via `logs_read`

**Setup on a new machine:**
1. Open the project in Godot 4.5
2. Enable the `godot_ai` plugin under Project → Project Settings → Plugins
3. The plugin will start the MCP server automatically
4. Open Claude Code in this directory — it will connect via `.claude/settings.json` permissions

## Behavior Notes

- Do not take editor or game screenshots to verify changes — the user tests the game directly and reports what to change. Only screenshot if explicitly asked.
- After code changes, rely on `project_run` or tell the user to run it; skip screenshot verification.
