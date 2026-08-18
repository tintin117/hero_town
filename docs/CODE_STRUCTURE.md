# Hero Town — Code Structure & Runtime Flow

This document describes how the game actually boots and runs today, and what every
`.gd` script in the active (non-archived) codebase does. It reflects the real state
of the project as read from `project.godot`, the scene files, and the scripts —
not the aspirational file list in `CLAUDE.md`.

Scope: `scenes/`, `scripts/`, `vfx/`, `tests/`, `data/`. The `bck/` folder (archived
Node2D prototype) and `addons/` (third-party/plugin code) are out of scope except
for a one-line mention of what they are.

---

## 1. Boot sequence

Godot reads `project.godot` on launch:

```
run/main_scene = "res://scenes/main_menu.tscn"

[autoload]
GameData            = scripts/game_data.gd
GameState           = scripts/game_state.gd
_mcp_game_helper    = addons/godot_ai/runtime/game_helper.gd   (editor plugin, not gameplay)
fx                  = vfx/fx.gd
```

Autoloads run first, before any scene node's `_ready()`, and stay alive for the
whole process. Load order is `GameData → GameState → _mcp_game_helper → fx`.

1. **`GameData`** (`scripts/game_data.gd`) scans `res://data/heroes/`,
   `res://data/enemies/`, `res://data/buildings/` for `.tres` resource files and
   loads them into three dictionaries keyed by each resource's `id`. This is the
   entire "database" of the game — 15 heroes, 6 enemies, 5 buildings today.
2. **`GameState`** (`scripts/game_state.gd`) holds the player's live save-state:
   gold, shards, and which heroes are owned. Starts with `gold = 5000`,
   `shard = 500` (placeholder debug values, not tuned economy numbers).
3. **`fx`** (`vfx/fx.gd`) is the global "juice" bus — screen shake, hit-stop,
   damage-number popups, particle effects. Any script can call `fx.spawn(...)`,
   `fx.shake(...)`, etc. from anywhere without a node reference.

Then `scenes/main_menu.tscn` loads and shows the menu.

### Menu → gameplay

`scripts/main_menu.gd` wires three buttons:

- **Play** → `get_tree().change_scene_to_file("res://scenes/test_3d_prototype.tscn")`
- **Compact** → resizes/repositions the OS window into a thin always-on-top
  transparent overlay strip (a "desktop pet" style mode), then loads the same
  `test_3d_prototype.tscn`.
- **Quit** → `get_tree().quit()`

**`test_3d_prototype.tscn` is the actual game scene** — despite the "prototype"
name, this is what `run/main_scene`'s Play button currently loads and is where
all real gameplay logic lives. Per `CLAUDE.md`, it's a placeholder until a
dedicated game scene replaces it, but as of now it *is* the game.

---

## 2. The game scene (`test_3d_prototype.tscn`)

Node tree (relevant nodes only):

```
Test3dPrototype (Node3D)
├─ Camera3D                      (fixed angle, orthographic-ish, current=true)
├─ Ground (MeshInstance3D)       — invisible plane, used only to size the grid
├─ PlacementController           — script: scenes/placement_controller.gd
├─ CanvasLayer                   — script: scenes/canvas_layer.gd  (all HUD/UI)
│   ├─ BuildingPopup             — instance of building_popup.tscn
│   ├─ PlacementButton           — "Place Building" button
│   ├─ BuildMenuPopup            — instance of build_menu_popup.tscn
│   ├─ Coin_HUD / Shard_HUD      — currency counters
│   └─ PanelContainer            — (empty placeholder)
├─ Hero                          — instance of hero.tscn, starts pre-placed
├─ Enemy                         — instance of enemy.tscn, starts pre-placed
├─ GridSystem                    — script: scenes/grid_system.gd
│   └─ GridVisual                — shader-drawn grid/hover-highlight overlay
├─ Sky                           — instance of sky.tscn (day/night cycle)
├─ FogVolume
└─ popupbook                     — decorative 3D prop
```

### Runtime flow, start to finish

1. `GridSystem._ready()` fits itself to the `Ground` mesh (`_fit_to_ground`),
   computes `cell_size`/`grid_cols` from the mesh size, builds the row/col
   occupancy array, sizes the `GridVisual` shader plane, and emits
   `grid_ready`.
2. `PlacementController._ready()` awaits `grid_ready`, then spawns the two
   **prebuilt buildings** (`town_hall` at cell (1,0), `shrine` at cell (1,2))
   and a **portal** at the rightmost column, via `_spawn_building()`. Each
   spawned `BuildingBase` is registered on the grid and hooked into
   `CanvasLayer` so clicking it opens the building popup.
3. Every frame, `GridSystem._process()` raycasts the mouse against the ground
   plane to compute `hovered_cell` and feeds it to the grid shader as a
   highlight.
4. **Building a new building:** Player clicks "Place Building" →
   `CanvasLayer._on_placement_button_pressed()` builds an options list from
   `GameData.BUILDINGS` (filtered to buildable types, i.e. non-negative cost)
   and shows `BuildMenuPopup`. Picking one emits `build_requested` →
   `CanvasLayer._on_build_requested` → `PlacementController.start_placement()`,
   which spawns a non-colliding "ghost" building that follows the hovered
   cell. Left-click on a free, affordable cell confirms the placement
   (spends gold, spawns the real building); right-click cancels.
5. **Moving a building:** Clicking an existing building emits `clicked` →
   `CanvasLayer._on_building_clicked` opens `BuildingPopup`. Its "Move"
   button emits `move_requested` → `PlacementController.start_move()`, which
   reuses the same ghost-drag flow but drags the existing node instead of
   instantiating a new one.
6. **Portal / spawning enemies:** `BuildingPopup`, when opened on the portal,
   lists every `EnemyData` whose `tier` is unlocked by the portal's current
   level and shows a "Summon" button per enemy. Pressing it emits
   `spawn_requested` → `CanvasLayer._on_spawn_requested`, which instantiates
   `enemy.tscn`, builds a `UnitStats` from the `EnemyData` row, and drops it
   at the portal's position.
7. **Shrine / gacha:** `BuildingPopup`, when opened on the shrine, shows a
   "Roll" button costing gold+shards (per shrine level). Rolling does a
   rarity-weighted pick over `GameData.HEROES`, adds the hero to
   `GameState.owned_heroes` (or converts a duplicate into shards), and — on a
   genuinely new hero — emits `hero_acquired` → `CanvasLayer._on_hero_acquired`,
   which instantiates `hero.tscn` at the shrine's position.
8. **Combat:** Heroes and enemies are both `Character` subclasses. Each
   independently chases the nearest member of the opposing group
   (`heroes`/`enemies` node groups) and auto-attacks on contact — there is no
   manual combat input, per the GDD's hard cuts. On death, `Enemy._on_death()`
   grants gold/shards to `GameState` (or spawns a decorative coin if it has no
   `EnemyData`, e.g. the scene's pre-placed debug Enemy).
9. **Currency HUD:** `CanvasLayer` listens to `GameState.currency_changed` and
   keeps the gold/shard labels in sync.

---

## 3. Autoload scripts (global singletons)

### `scripts/game_data.gd` — `GameData`
Static content database. On `_ready()`, walks the three `data/*` folders and
loads every `.tres` into a `Dictionary` keyed by `id`:
- `HEROES: Dictionary` — `HeroData` resources (15 rows, `data/heroes/h001.tres`…)
- `ENEMIES: Dictionary` — `EnemyData` resources (6 rows)
- `BUILDINGS: Dictionary` — `BuildingData` resources (5 rows: town_hall, shrine,
  portal, tavern, blacksmith)

Function: `_load_dir(path) -> Dictionary` — generic loader used for all three.

### `scripts/game_state.gd` — `GameState`
Player's mutable save-state (in-memory only, no persistence layer yet).
- `gold: int`, `shard: int`, `owned_heroes: Dictionary` (hero_id → true)
- `signal currency_changed(gold, shard)` — emitted on every spend/add
- `can_afford(gold_cost, shard_cost = 0) -> bool`
- `spend(gold_cost, shard_cost = 0) -> bool` — returns false and does nothing
  if unaffordable, otherwise deducts and emits the signal
- `add(gold_amount, shard_amount = 0)` — grants currency and emits the signal

### `vfx/fx.gd` — `fx`
Global game-feel/VFX bus, see [Section 6](#6-vfx-system-vfx). Not tied to any
one scene — call it from any script via the autoload name `fx`.

---

## 4. Core gameplay scripts (`scenes/`)

### `scenes/grid_system.gd` — class `GridSystem`
Owns the 3-row × N-col placement grid and its visual highlight.
- `_fit_to_ground()` — derives `origin`, `cell_size`, `grid_cols` from the
  `Ground` mesh's size/scale so the grid always exactly covers it.
- `grid_to_world(row, col) -> Vector3` / `world_to_grid(world_pos) -> Vector2i`
  — the two coordinate conversions everything else builds on.
- `is_within_bounds`, `is_free`, `occupy`, `clear` — occupancy bookkeeping
  over a `_occupancy[row][col]` array.
- `_process()` — raycasts the mouse to the ground plane every frame to update
  `hovered_cell` and push a `highlight_cell` shader parameter to `GridVisual`.
- `signal grid_ready` — fired once initial sizing is done; other scripts
  (`PlacementController`) `await` it before spawning anything.

### `scenes/building_base.gd` — class `BuildingBase`
The script behind `building_base.tscn`, instanced for every building
(town hall, shrine, portal, tavern, blacksmith all share this one scene).
- `@export building_id: String` — key into `GameData.BUILDINGS`.
- `get_data() -> BuildingData` — looks itself up in `GameData.BUILDINGS`.
- `_ready()` — applies the building's sprite texture, scales it to a fixed
  reference width, fits a box collider to the sprite's actual pixel bounds
  (`_fit_collision_to_sprite`), and registers itself on the `GridSystem`.
- `_on_area_input_event` — click detection via `Area3D`; emits `clicked`, and
  has a `suppress_next_click` guard so confirming a "move" doesn't re-open the
  popup on the same physics frame.
- `upgrade()` — increments `current_level` (cost/validation lives in the popup
  UI, not here).

### `scenes/placement_controller.gd`
Drives the drag-to-place / drag-to-move UX (no class_name — accessed by node
path, not by type).
- `PREBUILT_BUILDINGS` — the two buildings placed automatically at scene start
  (town hall, shrine); the portal is spawned separately in `_ready()` on the
  last grid column.
- `start_placement(data: BuildingData)` — begins placing a brand-new building:
  spawns a non-colliding ghost that tracks `grid_system.hovered_cell`.
- `start_move(building: BuildingBase)` — begins relocating an existing
  building: clears its old grid cell, disables its collider, and reuses the
  same ghost-follow logic with the real node as the "ghost".
- `_unhandled_input` — left-click on a free cell confirms placement/move
  (spending gold for new builds); right-click cancels either.
- `_cancel_placement` — restores a moved building to its original cell, or
  frees a not-yet-placed ghost.

### `scenes/canvas_layer.gd`
The HUD/UI controller — owns all popups and wires their signals to game
logic (no class_name, root of the `CanvasLayer` node in the game scene).
- Connects `BuildMenuPopup.build_requested`, `BuildingPopup.move_requested`,
  `BuildingPopup.spawn_requested`, `BuildingPopup.hero_acquired`, and
  `GameState.currency_changed`.
- `connect_building(building)` — called once per spawned `BuildingBase` so its
  `clicked` signal opens `BuildingPopup`.
- `_on_spawn_requested` / `_on_hero_acquired` — the only two places that
  instantiate `enemy.tscn` / `hero.tscn` at runtime, building a `UnitStats`
  from the relevant data row before adding the unit to the scene.

### `scripts/character.gd` — class `Character` (`extends CharacterBody3D`)
Shared base class for both `Hero` and `Enemy`. All combat logic lives here;
subclasses only decide *who to chase* and a couple of small behavior hooks.
- State machine: `MOVE → COMBAT → KNOCKBACK → DEAD` (enum `State`).
- `@export stats: UnitStats` — hp/atk/speed/range, assigned at spawn time.
- `_chase_and_engage(opponent_group)` — steers toward the nearest `Character`
  in the given node group, or calls `_enter_combat` once in range. This is
  the one method subclasses call from their `_update_move` override.
- `_enter_combat` / `_exit_combat` — starts/stops a per-instance attack
  `Timer` (interval = `stats.atk_speed`).
- `_on_attack_timeout` — fires on the timer; deals `stats.atk` damage to
  `target` if still in range.
- `take_damage(amount, attacker)` — applies damage, updates the health-bar
  sprite, triggers `spawn_fx`, and on death sets `state = DEAD`, calls the
  `_on_death()` hook, emits `died`, and frees itself. Otherwise may apply
  knockback via `_should_knockback` (virtual, overridable per subclass).
- `spawn_fx(value)` — projects the character's world position to screen
  space and calls `fx.spawn("impact_spark", ...)`, `fx.shake`, `fx.hitstop`,
  and `fx.popup(str(value), ...)` for the floating damage number.
- Virtual/override points subclasses use: `_update_move`, `_idle_move`,
  `_should_knockback`, `_on_death`.

### `scripts/hero.gd` — class `Hero extends Character`
- Joins the `"heroes"` group.
- `_update_move` → `_chase_and_engage("enemies")`.
- `_idle_move` → `_patrol()` between `patrol_start_x`/`patrol_end_x` when no
  enemy is in the world (idle back-and-forth walk).
- `_should_knockback` → only bosses (`Enemy.is_boss`) can knock a hero back.

### `scripts/enemy.gd` — class `Enemy extends Character`
- Joins the `"enemies"` group.
- `@export is_boss`, `@export enemy_data: EnemyData` (may be null for
  hand-placed debug enemies).
- `_update_move` → `_chase_and_engage("heroes")`.
- `_idle_move` → walks in a fixed `move_direction` when no hero is nearby.
- `_on_death` → grants a random gold/shard amount (from `enemy_data`'s
  min/max range) to `GameState`; if `enemy_data` is null, spawns a cosmetic
  `coin.tscn` instead (used by the scene's pre-placed debug Enemy, which has
  no data assigned).

### `scenes/coin.gd`
Cosmetic-only: a `Node2D` that waits 1s, then tweens itself to the currency
HUD icon and fades out. No gameplay effect — purely visual feedback for the
data-less debug enemy's death (see above). Screen-space UI, not connected to
`GameState`.

### `scenes/sky.gd` (`@tool`)
Procedural day/night cycle driver for `sky.tscn`. Computes sun/moon rotation
and light energy from `day_time`/`day_of_year`/`latitude`, and can drive a
sky shader's time uniform independently of the engine clock
(`use_day_time_for_shader`). Runs in-editor too (`@tool`) so it previews
correctly in the editor viewport. Not gameplay-critical.

### `scenes/animation_button.gd` — class `AnimationButton extends TextureButton`
Small hover/focus polish for menu buttons: scales/brightens on
`mouse_entered`/`focus_entered`, reverts on exit. Used by the main menu's
Play/Compact/Quit buttons.

### `scripts/main_menu.gd`
See [Section 1](#1-boot-sequence) — Play/Compact/Quit handlers.

---

## 5. UI popup scripts (`scripts/`)

### `scripts/build_menu_popup.gd`
Backs `build_menu_popup.tscn`. `show_options(options: Array)` rebuilds a list
of buttons (one per buildable `BuildingData`, thumbnail + cost), disabling any
the player can't afford. Picking one emits `build_requested(building_type)`
and hides itself.

### `scripts/building_popup.gd`
Backs `building_popup.tscn`. The single popup used for *every* building type
— title/level/upgrade button are generic, and `_refresh()` branches on
`building.building_id` to append type-specific content:
- **portal** → `_refresh_enemy_list` — lists summonable enemies up to the
  portal's unlocked tier, each with a "Summon" button (`spawn_requested`).
- **shrine** → `_refresh_shrine_content` — shows the roll cost and a "Roll"
  button; `_on_roll_button_pressed` does the weighted-rarity gacha pull
  (`_weighted_pick`) against `GameState`'s currency, updating
  `GameState.owned_heroes` and emitting `hero_acquired` on a new hero.
- any other building → no extra content, just upgrade.
`_on_upgrade_button_pressed` spends gold per `BuildingData.levels[level].cost`
and calls `building.upgrade()`. `move_requested` is emitted by the Move
button and handled by `CanvasLayer`.

---

## 6. Data model (`scripts/resources/`, `data/`)

Three plain `Resource` subclasses define the schema for the `.tres` content
files `GameData` loads; `UnitStats` is the runtime stat block assigned to
spawned `Character`s.

| Script | class_name | Fields | Backing files |
|---|---|---|---|
| `scripts/resources/hero_data.gd` | `HeroData` | id, display_name, rarity, hero_class, base_power, power_per_level, base_hp, atk_speed, crit_chance, upgrade_gold_base, upgrade_shard_base, dupe_shard, th_unlock | `data/heroes/h001–h015.tres` |
| `scripts/resources/enemy_data.gd` | `EnemyData` | id, display_name, tier, hp, atk, def, spawn_time, gold_min/max, shard_min/max | `data/enemies/e001–e006.tres` |
| `scripts/resources/building_data.gd` | `BuildingData` | id, display_name, build_cost, unlock_th_level, thumbnail, sprite_texture, levels (Array[Dictionary] — per-level cost/tier/roll data) | `data/buildings/{town_hall,shrine,portal,tavern,blacksmith}.tres` |
| `scripts/unit_stats.gd` (`@tool`) | `UnitStats` | max_hp, atk, atk_speed, move_speed, attack_range | n/a — constructed at spawn time from a `HeroData`/`EnemyData` row (see `canvas_layer.gd`) |

`HeroData`/`EnemyData`/`BuildingData` are static design content (read-only at
runtime); `UnitStats` is the live, per-instance combat stat block `Character`
actually uses each frame.

---

## 7. VFX system (`vfx/`)

Small, self-contained game-feel layer, independent of gameplay logic.

### `vfx/fx.gd` — autoload `fx`
- `EFFECTS: Dictionary` — name → scene path registry (`impact_spark`,
  `shockwave`, `hit_flash`, `hit_burst`, `pickup_sparkle`, `smoke_pop`).
- `spawn(effect_name, global_pos, opts) -> FxEffect` — instantiates and
  configures a registered effect scene.
- `shake(strength, duration)` — tweens the active `Camera3D`'s h/v pixel
  offset in a decaying random walk.
- `hitstop(duration, time_scale)` — briefly dips `Engine.time_scale` for a
  freeze-frame hit; re-entrant calls are ignored while one is in flight
  (`_hitstop_busy` guard).
- `flash(color, duration, max_alpha)` — full-screen color flash via a
  lazily-created top-layer `ColorRect`.
- `popup(text, global_pos, opts)` — the floating damage-number label (tween:
  scale-in, drift-up, fade, free). This is what `Character.spawn_fx` calls
  for every hit.

### `vfx/fx_effect.gd` — class `FxEffect extends Node2D`
Base class every effect scene (`hit_burst.tscn`, `hit_flash.tscn`,
`impact_spark.tscn`, `shockwave.tscn`, `pickup_sparkle.tscn`,
`smoke_pop.tscn`) extends. Defines the play/stop lifecycle
(`play → _play → _duration timer → _on_done → optional queue_free`) and a
library of static texture/material-generation helpers (`make_dot_texture`,
`make_streak_texture`, `make_ramp`, `make_add_material`, `make_star_sprite`,
etc.) so individual effects don't each hand-roll gradient/particle textures.
Each concrete effect script under `vfx/effects/**/*.gd` overrides `_build`,
`_play`, `_duration`, and optionally `_apply_colors`/`_stop`/`_reset`.

---

## 8. Legacy / unused / scratch code

Worth knowing about so it isn't mistaken for active systems:

- **`scenes/layer.gd`** — an earlier, simpler slot-based placement system
  (`occupied_slots`, `place_building(start, end, building)` operating on
  1D integer slots along an X axis). **Not referenced by any `.tscn` in the
  project** — it was superseded by `GridSystem` + `BuildingBase` +
  `PlacementController`. Safe to ignore/delete if you're mapping the active
  systems; not wired into `test_3d_prototype.tscn`.
- **`scenes/player_test_25.gd`**, **`scenes/test_25_camera.gd`**,
  `scenes/level_test_25.tscn` — an isolated WASD `CharacterBody3D` movement
  scratch test (Godot's stock "3D top-down" template movement code). Not
  reachable from the main menu or the game scene; a standalone scene you'd
  open directly in the editor to test something unrelated to the town-builder
  loop.
- **`bck/`** — the archived pre-3D-rebuild prototype (Node2D heroes, enemies,
  buildings, main loop). Per `CLAUDE.md`, do not read/port from here unless
  explicitly asked.
- **`addons/godot_ai/`** — the MCP server plugin that lets Claude Code read
  and edit the Godot project live. Not gameplay code; don't modify.
- **`addons/ridiculous_coding/`** — a third-party "screen-shake while you
  type code" editor plugin (cosmetic developer-experience addon, unrelated
  to the game).

---

## 9. Tests (`tests/`)

### `tests/test_grid_system.gd`
A `@tool`, `McpTestSuite`-based unit test (run via the Godot AI plugin's test
runner) covering `GridSystem`'s pure coordinate math in isolation (no scene
tree needed):
- `test_grid_to_world_round_trip` — `grid_to_world` → `world_to_grid` returns
  the original cell for every row × {0, 4, 9} column.
- `test_world_to_grid_out_of_bounds` — a far-away world position resolves to
  the `Vector2i(-1, -1)` sentinel.
- `test_occupancy` — `is_free`/`occupy`/`clear` behave as a basic
  read-after-write occupancy map.

---

## 10. Quick reference: script → responsibility

| Script | Responsibility |
|---|---|
| `game_data.gd` | Load static content (heroes/enemies/buildings) from `.tres` files |
| `game_state.gd` | Player's live gold/shard/owned-heroes state |
| `main_menu.gd` | Menu button handlers, scene transition into the game |
| `grid_system.gd` | Grid math, occupancy, hover highlight |
| `building_base.gd` | Per-building instance: sprite, collider, click, level |
| `placement_controller.gd` | Ghost-drag placement & move UX |
| `canvas_layer.gd` | HUD wiring: popups ↔ game logic, currency labels |
| `build_menu_popup.gd` | "Choose a building to build" popup |
| `building_popup.gd` | Per-building detail popup: upgrade, summon, gacha roll |
| `character.gd` | Shared combat state machine for heroes & enemies |
| `hero.gd` | Hero-specific chase/patrol behavior |
| `enemy.gd` | Enemy-specific chase/wander behavior, death rewards |
| `coin.gd` | Cosmetic coin-collect animation |
| `sky.gd` | Day/night lighting cycle |
| `animation_button.gd` | Hover/focus button polish |
| `unit_stats.gd`, `hero_data.gd`, `enemy_data.gd`, `building_data.gd` | Data schemas |
| `fx.gd`, `fx_effect.gd`, `vfx/effects/**` | Screen shake, hit-stop, damage popups, particles |
| `layer.gd` | Unused legacy placement system |
| `player_test_25.gd`, `test_25_camera.gd` | Unrelated movement scratch test |
