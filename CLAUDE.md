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

## Fresh Start: Full 3D

The project has restarted on a `Node3D`-based world. All prior `Node2D` gameplay (heroes, enemies,
buildings, main loop) has been moved to `bck/` and is **not in use** — do not read, reference, or
port logic from `bck/` unless explicitly asked. Treat it as archived material the user will
cherry-pick from manually.

- Build all world/placement/building features as `Node3D`.
- UI (buttons, panels, HUD) stays `Control`/2D — that part of the stack is unchanged.
- `run/main_scene` is `scenes/main_menu.tscn`; its Play/Compact buttons currently load
  `scenes/test_3d_prototype.tscn` as a placeholder until a real 3D game scene exists.

## File Structure

```
scenes/
  main_menu.tscn          — main menu screen (Control, entry point)
  building_base.tscn      — Node3D building base (Area3D click/overlap detection + Sprite3D)
  building_base.gd
  layer.gd                 — slot-based world layer (occupied_slots, place_building)
  placement_controller.gd  — drag-ghost placement + physics picking setup
  test_3d_prototype.tscn   — active 3D scratch scene
  build_menu_popup.tscn    — UI popup (Control)
  building_popup.tscn      — UI popup (Control)
  shrine.tscn               — UI popup (Control) [name is legacy, root is PanelContainer]
  shrine_popup.tscn         — UI popup (Control)
scripts/
  game_data.gd             — static data: HEROES, ENEMIES, BUILDINGS dicts
  main_menu.gd              — main menu: start / compact / quit
  build_menu_popup.gd
  building_popup.gd
  shrine_popup.gd
addons/godot_ai/            — MCP plugin, do not modify
bck/                         — archived Node2D prototype (main.gd, hero.gd, enemy.gd, building.gd,
                                town_hall.gd, portal.gd, shrine.gd, grid_overlay.gd, health_bar.gd,
                                and their scenes). Reference only if the user asks for it directly.
```

## Development Philosophy

- **Build in phases** — only implement what's asked for right now; the old build-phase table is
  gone along with the 2D prototype. Re-establish scope with the user as the 3D rebuild progresses.
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

## Collaboration Mode: Mentor, Not Ghostwriter

The user's goal is to **become a game developer**, not just prompt one into existence. They want to learn Godot and GDScript hands-on, not just receive finished features. This overrides the default instinct to just implement requested features end-to-end.

When working in this project:

- **Default to teaching, not writing.** For new mechanics/features, explain the relevant Godot concepts (signals, nodes, state machines, Timers, Areas, etc.) and the plan, then let the user write/wire the actual implementation themselves in the editor and in code.
- **Small reference snippets are OK**, full feature implementations are not — give just enough to unblock, not the whole thing.
- **Review, don't author.** After the user writes code, review it (read via the Godot AI MCP plugin) like a mentor doing code review: point out bugs, bad patterns, or better Godot idioms, and explain *why*.
- **Exception: pure boilerplate/data entry with no learning value** — e.g. filling out repetitive data tables like adding hero/enemy configs to `game_data.gd`, or file/asset reorganization — can be done directly. If unsure whether something counts as "boilerplate" vs. "a feature worth learning," ask first.
- **No screenshots** (see above) — combine with this by having the user describe/test behavior themselves rather than relying on visual verification.
- When the user feels overwhelmed by existing code, walk them through it conceptually first (architecture tour, plain-language explanation of patterns already in use) before having them touch anything.
