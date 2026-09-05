# Hero Town — Claude Code Context

## Project Identity

A Steam demo inspired by **Crusaders Quest: Hero Town** (idle RPG town builder) in Godot 4.5.
- Steam page: https://store.steampowered.com/app/4126220/Crusaders_Quest__Hero_Town/
- Genre: Idle RPG + Town Building, pixel art style
- Core appeal: heroes auto-fight enemies while the player manages a small town

## GDD Location

Full design specs live in: `D:\Optics Team\Godot\[Optics] Hero_Town_GDD\`

Key files:
- `Overview.html` — product shape, hard cuts, demo end condition
- `Current Plan.html` — build targets (B1 / B2 / B3) with acceptance criteria
- `Detail Planning.html` — task-level breakdown per build
- `Hero.html` — all 15 hero configs (stats, rarity, unlock gates)
- `Enemy.html` — all 10 enemy configs (tiers, drops, boss flag)
- `Building.html` — Town Hall, Portal, Shrine, Tavern, Blacksmith level tables
- `Economy.html` — currency rules, drop scaling, milestone rewards
- `Progression.html` — TH gate → hero cap → portal tier mapping
- `Portal_Combat.html` — combat formulas, respawn, crit timing
- `Shrine.html` — gacha odds per shrine level, duplicate conversion
- `UI_UX.html` — screen priorities per build

## Tech Stack

- Godot 4.5, Forward Plus renderer, Jolt Physics, D3D12 (Windows)
- GDScript only
- Godot AI MCP plugin (`addons/godot_ai`) — enables Claude Code to read/write scenes and scripts directly via the editor

## 2D Pixel Art (Tiny Swords)

The project is built as a `Node2D` world using the Tiny Swords (Free Pack) CC0 asset pack
(`asset/Tiny Swords (Free Pack)/`). The `run/main_scene` is `scenes/main_menu.tscn`; its Play/Compact
buttons load `scenes/town_2d.tscn`, the active game scene.

## File Structure

```
scenes/
  main_menu.tscn          — main menu screen (Control, entry point)
  town_2d.tscn             — active 2D game scene
  board_2d.gd              — 2D board setup
  grid_system.gd            — grid/slot logic
  layer.gd                  — slot-based world layer (occupied_slots, place_building)
  placement_controller.gd   — drag-ghost placement
  building_base.tscn/.gd    — building base (Area2D click/hover + Sprite2D)
  hero_town_camera.tscn/.gd — camera
  day_night.gd               — day/night grading
  hero.tscn / enemy.tscn     — hero/enemy scenes
  build_menu_popup.tscn      — UI popup (Control)
  building_popup.tscn        — UI popup (Control)
  shrine_popup.tscn           — UI popup (Control)
scripts/
  game_data.gd             — static data: HEROES, ENEMIES, BUILDINGS dicts
  character.gd / hero.gd / enemy.gd — combat/movement logic
  main_menu.gd              — main menu: start / compact / quit
  build_menu_popup.gd
  building_popup.gd
  shrine_popup.gd
addons/godot_ai/            — MCP plugin, do not modify
```

## Development Philosophy

- **Build in phases** — only implement what's asked for right now. Re-establish scope with the
  user as the 2D build progresses.
- **No premature abstraction** — three similar lines beats a helper no one needs yet
- **No speculative features** — hard cuts: no manual combat, no decorations, no dialogue trees

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
