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

## File Structure

```
scenes/
  main.tscn         — root scene (1152×648 viewport)
  main_menu.tscn    — main menu screen
  hero.tscn         — hero CharacterBody2D
  enemy.tscn        — enemy CharacterBody2D
scripts/
  main.gd           — game manager: gold/shards, enemy spawning, building upgrades, save/load, overlay mode
  hero.gd           — hero AI: IDLE ↔ COMBAT state machine, level/stats, upgrade costs
  enemy.gd          — enemy AI: walk toward hero, attack on range, die → emit drops
  building.gd       — base building script (level, upgrade, signal)
  town_hall.gd      — Town Hall: hero level cap logic
  portal.gd         — Portal: enemy tier pool, spawn timer, upgrade
  health_bar.gd     — drawn health bar (Node2D using _draw, color-coded)
  grid_overlay.gd   — tile grid drawn during placement mode
  game_data.gd      — static data: HEROES, ENEMIES, BUILDINGS dicts
  main_menu.gd      — main menu: start / quit
addons/godot_ai/    — MCP plugin, do not modify
```

## Key Constants

| Constant | Value | Location |
|---|---|---|
| `GROUND_Y` | 500.0 | main.gd (hero/enemy walk line) |
| `ENEMY_SPAWN_X` | 1050.0 | main.gd |
| `SAVE_PATH` | `user://save.json` | main.gd |
| Viewport | 1152 × 648 | project settings |

## Build Phases

The demo is scoped into three builds. **Do not implement features beyond the current build.**

### Build 1 — Core loop proof (`v0.1.0`)
Acceptance: player summons enemy, hero kills it, receives drops, upgrades Town Hall / Portal.

| Feature | Status |
|---|---|
| Hero H001 (Militia Ratcatcher) auto-fights enemies | ✅ Done |
| Enemies E001 (Cave Slime) + E002 (Tunnel Goblin), tiers 1-2 | ✅ Done |
| Town Hall Lv1-2 (hero level cap gate) | ✅ Done |
| Portal Lv1-2 (enemy tier unlock) | ✅ Done |
| Gold + Shards economy, save/load (`user://save.json`) | ✅ Done |
| Hero card UI (level, power, upgrade button) | ✅ Done |
| Building panel UI (TH + Portal) | ✅ Done |
| Main menu | ✅ Done |
| Compact / overlay window mode | ✅ Done |
| Hero respawn after death (10 s delay, no permanent death) | ❌ Missing — hero currently resets HP instantly |
| First-kill milestone reward (+50g +5s) | ✅ Done (`first_kill_done` flag) |

### Build 2 — Shrine + hero acquisition (`v0.2.0`)
Acceptance: player rolls heroes at Shrine, upgrades hero with gold+shard, reaches Portal Lv3.

| Feature | Status |
|---|---|
| Shrine building (scene node + script) | ❌ Not started |
| Shrine gacha roll (gold + shard cost, rarity weights) | ❌ Not started |
| Shrine panel UI (roll button, cost, result reveal, duplicate → shards) | ❌ Not started |
| Shrine Lv1-2 unlock at TH Lv2 | ❌ Not started |
| Hero roster — multiple heroes, active slot(s) | ❌ Not started |
| All 15 hero configs in `game_data.gd` (H001–H015) | ❌ Partial — only H001 |
| Enemies E003–E006 in `game_data.gd` (Tiers 2-3) | ❌ Partial — only E001-E002 |
| Portal Lv3 (Tier 3 enemies, 2 active enemy slots) | ❌ Not started |
| TH Lv3 unlock (hero cap 30) | ❌ Not started |
| Crit system (crit_chance per hero, enabled Build 2+) | ❌ Not started |
| Milestone M002 (TH Lv2 upgrade → +100g +10s) | ❌ Not started |
| Milestone M003 (first shrine roll → +20s) | ❌ Not started |
| Collection Book UI (discovered heroes, silhouettes for undiscovered) | ❌ Not started |

### Build 3 — Vertical demo (`v0.3.0`)
Acceptance: player reaches Portal Lv5, defeats Dungeon Heart boss, 10+ min play session.
> Do not start Build 3 features until Build 2 acceptance is met.

Planned: Tavern (visitor heroes), Blacksmith (power bonus), Portal Lv4-5, TH Lv4-5, Enemies E007–E010 (Tiers 4-5 + boss), Demo goal tracker UI, Settings/audio panel.

## Core Game Loop

```
Upgrade TH / Portal → Summon enemies via Portal → Heroes auto-fight
→ Collect Gold + Shards → Roll heroes at Shrine / upgrade hero
→ Push higher portal tier → repeat → defeat Portal Lv5 boss
```

## Data Reference (game_data.gd)

- **Heroes**: 15 total (H001–H015), Common → Legendary. Only H001 is implemented.
- **Enemies**: 10 total (E001–E010), Tiers 1–5. Only E001–E002 are implemented.
- **Buildings**: Town Hall (5 lvl), Portal (5 lvl), Shrine (5 lvl), Tavern (3 lvl), Blacksmith (3 lvl).
  Only TH Lv1-2 and Portal Lv1-2 are implemented.

Hero formula: `power = base_power + (level - 1) * power_per_level`
Hero upgrade cost: `gold = ROUND(base_gold * level^1.35)` / `shards = ROUND(base_shard * level^1.20)`
Hero max level: `Town Hall level * 10`
Damage: `MAX(1, hero_atk - enemy_def)`

## Development Philosophy

- **Build in phases** — only implement what the current build requires
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
- **Exception: pure boilerplate/data entry with no learning value** — e.g. filling out repetitive data tables like adding hero/enemy configs to `game_data.gd` — can be done directly. If unsure whether something counts as "boilerplate" vs. "a feature worth learning," ask first.
- **No screenshots** (see above) — combine with this by having the user describe/test behavior themselves rather than relying on visual verification.
- When the user feels overwhelmed by existing code, walk them through it conceptually first (architecture tour, plain-language explanation of patterns already in use) before having them touch anything.
